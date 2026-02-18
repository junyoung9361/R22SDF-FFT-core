clear all;
close all;
clc;

%% ================= 1. Parameter Setting ================= %%
N = 1024;
total_stages = log2(N);
IS_INVERSE = 1; % true: IFFT, false: FFT            


WL = 16;        % WORD LENGTH
FL_data = 10;   % DATA FRACTIONAL BIT WIDTH
FL_twid = 15;   % TWIDDLE FACTOR FACTIONAL BIT WIDTH
SCENARIO = 3;   % INPUT DATA

limit_max = 2^(WL-1) - 1;
limit_min = -2^(WL-1);

% input data Scenario Selection
% input data Scenario Selection
switch SCENARIO
    case 1 % Impulse
        senario_name = 'impulse';
        din_re = zeros(1, N);
        din_im = zeros(1, N);
        din_re(1) = 0.99;
    case 2 % Constant (DC)
        senario_name = 'constant';
        din_re = 0.5 * ones(1, N);
        din_im = 0.2 * ones(1, N);
    case 3 % Tone 4 Frequencies
        senario_name = 'tone4';
        t = 0: N-1;
        freqs = [8, 32, 64, 128];
        sig_Sum = 0;
        for f = freqs
            sig_Sum = sig_Sum + 0.2 * exp(1j * 2 * pi * f * t / N);
        end
        din_re = real(sig_Sum);
        din_im = imag(sig_Sum);
    case 4 % Normalize Input
        senario_name = 'nomarlized_random';
        scale_factor = 0.3;
        din_re = scale_factor * randn(1, N);
        din_im = scale_factor * randn(1, N);
    case 5 % Fixed Random
        senario_name = 'nomarlized_fix';
        rng(777);
        scale_factor = 0.5;
        din_re = scale_factor * randn(1, N);
        din_im = scale_factor * randn(1, N);
    case 6 % IFFT Verification
        senario_name = 'ifft_verify';
        freq_bins = zeros(1, N);
        target_freq = 10;                
        freq_bins(target_freq + 1) = 0.8;
        din_re = real(freq_bins);
        din_im = imag(freq_bins);
    otherwise
        error('Invalid Scenario Selected');
end

input_re = zeros(1, N);
input_im = zeros(1, N);

if IS_INVERSE
    fft_ref = ifft(din_re + 1j * din_im);    % IFFT Reference
else
    fft_ref = fft(din_re + 1j * din_im) / N; % FFT Reference
end

% Quantization
curr_re = zeros(1, N);
curr_im = zeros(1, N);
for i=1:N
    curr_re(i) = quantization(din_re(i), WL, FL_data);
    curr_im(i) = quantization(din_im(i), WL, FL_data);
end

% Export Input Data
file_name = sprintf('input_data_%s_%d.bin', senario_name, N); 
fid = fopen(file_name, 'wb');
for i = 1:N
    re_hex = bitand(int32(curr_re(i)), 2^WL-1); 
    im_hex = bitand(int32(curr_im(i)), 2^WL-1);
    word32 = bitor(bitshift(uint32(re_hex), 16), uint32(im_hex));
    fwrite(fid, word32, 'uint32');
end
fclose(fid);

% Select Mode
if IS_INVERSE
    curr_im = -curr_im;
end

%% ================= 2. R2^2 SDF FFT ================= %%
stages_processed = 0;
current_stage_idx = 0; 

if mod(total_stages, 2) == 1
    num_macros = (total_stages - 1) / 2;
    NUM_ROM_STAGES = num_macros + 1;
else
    num_macros = total_stages / 2;
    NUM_ROM_STAGES = num_macros;
end

% for head debugging
bf_head_re  = zeros(1, N);
bf_head_im  = zeros(1, N);
cnm_head_re = zeros(1, N);
cnm_head_im = zeros(1, N);
rom_head_re = zeros(1, N);
rom_head_im = zeros(1, N);

% Head Stage (Radix-2)
if mod(total_stages, 2) == 1
    current_stage_idx = current_stage_idx + 1;
    
    M = N; D = M / 2;
    for k = 0 : D - 1
        idx_a = k + 1;
        idx_b = k + D + 1;
        
        [sum_re, sum_im, diff_re, diff_im] = butterfly(curr_re(idx_a), curr_im(idx_a), curr_re(idx_b), curr_im(idx_b));
        curr_re(idx_a) = sum_re;
        curr_im(idx_a) = sum_im;
        curr_re(idx_b) = diff_re;
        curr_im(idx_b) = diff_im;
        
        bf_head_re(1, idx_a) = sum_re;
        bf_head_im(1, idx_a) = sum_im;
        bf_head_re(1, idx_b) = diff_re;
        bf_head_im(1, idx_b) = diff_im;
        
        angle = -2 * pi * k / M;
        [mul_re, mul_im, w_re, w_im] = complex_mult(diff_re, diff_im, angle, FL_twid, WL);
        rom_head_re(1, k+1) = w_re;
        rom_head_im(1, k+1) = w_im;
        
        curr_re(idx_a) = sum_re;
        curr_im(idx_a) = sum_im;
        curr_re(idx_b) = mul_re;
        curr_im(idx_b) = mul_im;
        
        cnm_head_re(1, idx_a) = curr_re(idx_a);
        cnm_head_im(1, idx_a) = curr_im(idx_a);
        cnm_head_re(1, idx_b) = curr_re(idx_b);
        cnm_head_im(1, idx_b) = curr_im(idx_b);
    end
    stages_processed = 1;
end

% Macro Stages (Radix2^2)
num_stages = (total_stages - stages_processed) / 2;
current_N = N / (2^stages_processed);

% for Debugging
bf1_re = zeros(num_stages, N); bf1_im = zeros(num_stages, N);
triv_re = zeros(num_stages, N); triv_im = zeros(num_stages, N);
bf2_re = zeros(num_stages, N); bf2_im = zeros(num_stages, N);
cnm_re = zeros(num_stages, N); cnm_im = zeros(num_stages, N);
rom_buf_re = zeros(num_stages, N);
rom_buf_im = zeros(num_stages, N);

for stage = 1 : num_stages
    M = current_N;         
    current_stage_idx = current_stage_idx + 1; 
    M1 = M;                
    D1 = M1 / 2;           
    num_groups_1 = N / M1; 
    
    % === BF1 Stage ===
    for g = 0 : num_groups_1 - 1
        offset = g * M1;       
        for k = 0 : D1 - 1
            idx_a = offset + k + 1;       
            idx_b = offset + k + D1 + 1; 

            [sum_re, sum_im, diff_re, diff_im] = butterfly(curr_re(idx_a), curr_im(idx_a), curr_re(idx_b), curr_im(idx_b));
            
            curr_re(idx_a) = sum_re;
            curr_im(idx_a) = sum_im;
            curr_re(idx_b) = diff_re;
            curr_im(idx_b) = diff_im;

            bf1_re(stage, idx_a) = sum_re;
            bf1_im(stage, idx_a) = sum_im;
            bf1_re(stage, idx_b) = diff_re;
            bf1_im(stage, idx_b) = diff_im;
        end
    end
    triv_re(stage, :) = bf1_re(stage, :);
    triv_im(stage, :) = bf1_re(stage, :);
 
    % Trivial Logic (-j)
    for g = 0 : num_groups_1 - 1
        offset = g * M1;
        for k = D1/2 : D1 - 1           
            idx = offset + k + D1 + 1;
            
            re_val_int = int32(curr_re(idx));
            im_val_int = int32(curr_im(idx));
            
            new_re = im_val_int;
            new_im = -re_val_int;
            
            curr_re(idx) = double(new_re);
            curr_im(idx) = double(new_im);
            
            triv_re(stage, idx) = curr_re(idx);
            triv_im(stage, idx) = curr_im(idx);
        end
    end
    
    % === BF2 Stage ===    
    M2 = M1 / 2;   
    D2 = M2 / 2;   
    num_groups_2 = N / M2; 
    
    bf2_re(stage, :) = triv_re(stage, :);
    bf2_im(stage, :) = triv_im(stage, :);
    
    for g = 0 : num_groups_2 - 1
        offset = g * M2;
        for k = 0 : D2 - 1
            idx_a = offset + k + 1;        
            idx_b = offset + k + D2 + 1;   
            [sum_re, sum_im, diff_re, diff_im] = butterfly(curr_re(idx_a), curr_im(idx_a), curr_re(idx_b), curr_im(idx_b));
            curr_re(idx_a) = sum_re;
            curr_im(idx_a) = sum_im;
            curr_re(idx_b) = diff_re;
            curr_im(idx_b) = diff_im;

            bf2_re(stage, idx_a) = sum_re;
            bf2_im(stage, idx_a) = sum_im;
            bf2_re(stage, idx_b) = diff_re;
            bf2_im(stage, idx_b) = diff_im;
        end
    end
    
    cnm_re(stage, :) = bf2_re(stage, :);
    cnm_im(stage, :) = bf2_im(stage, :);

    % === Complex Mult ===
    if stage ~= num_stages
        D_twid = M / 4;              
        num_groups_twid = N / M;     
        for g = 0 : num_groups_twid - 1
            base = g * M;
            for k = 0 : D_twid - 1
                idx0 = base + k + 1;               
                idx1 = base + k + D_twid + 1;      
                idx2 = base + k + 2*D_twid + 1;    
                idx3 = base + k + 3*D_twid + 1;    
                
                % bypass
                w0_bypass = limit_max; % 32767
                in_re = int32(curr_re(idx0));
                in_im = int32(curr_im(idx0));
                w_val = int32(w0_bypass);
                mul_re = in_re * w_val;
                mul_im = in_im * w_val;
                
                % trucation
                out_re = bitsra(mul_re, FL_twid); 
                out_im = bitsra(mul_im, FL_twid);
                
                cnm_re(stage, idx0) = double(out_re);
                cnm_im(stage, idx0) = double(out_im);
                
                curr_re(idx0) = double(out_re);
                curr_im(idx0) = double(out_im);
                rom_buf_re(stage, idx0) = w0_bypass;
                rom_buf_im(stage, idx0) = 0;

                % 2k
                angle = -2*pi*(2*k)/M;
                [curr_re(idx1), curr_im(idx1), w1r, w1i] = complex_mult(curr_re(idx1), curr_im(idx1), angle, FL_twid, WL);
                cnm_re(stage, idx1) = curr_re(idx1);
                cnm_im(stage, idx1) = curr_im(idx1);
                rom_buf_re(stage, idx1) = w1r;
                rom_buf_im(stage, idx1) = w1i;

                % k
                angle = -2*pi*k/M;
                [curr_re(idx2), curr_im(idx2), w2r, w2i] = complex_mult(curr_re(idx2), curr_im(idx2), angle, FL_twid, WL);
                cnm_re(stage, idx2) = curr_re(idx2);
                cnm_im(stage, idx2) = curr_im(idx2);
                rom_buf_re(stage, idx2) = w2r;
                rom_buf_im(stage, idx2) = w2i;

                % 3k
                angle = -2*pi*(3*k)/M;
                [curr_re(idx3), curr_im(idx3), w3r, w3i] = complex_mult(curr_re(idx3), curr_im(idx3), angle, FL_twid, WL);
                cnm_re(stage, idx3) = curr_re(idx3);
                cnm_im(stage, idx3) = curr_im(idx3);
                rom_buf_re(stage, idx3) = w3r;
                rom_buf_im(stage, idx3) = w3i;
            end
        end
    end
    current_N = current_N / 4;
end


%% ================= 3. Bit reverse ================= %%
dout_re = zeros(1, N);
dout_im = zeros(1, N);
num_bits = log2(N);
rev_debug = zeros(1, N);
for i = 0:N-1
    rev = bin2dec(reverse(dec2bin(i, num_bits)));
    res_re = curr_re(i + 1);
    res_im = curr_im(i + 1);
    if IS_INVERSE
        res_im = -res_im; % Output Conjugate
    end
    rev_debug(1, i+1) = rev;
    dout_re(rev + 1) = res_re;
    dout_im(rev + 1) = res_im;
end

%% ================= Output file Export ================= %%
file_name = sprintf('output_data_%s_%d.bin', senario_name, N); 
fid = fopen(file_name, 'wb');
for i = 1:N
    out_re = dout_re(1, i);
    out_im = dout_im(1, i);
    re_hex = bitand(int32(out_re), 2^WL-1); 
    im_hex = bitand(int32(out_im), 2^WL-1);
    word32 = bitor(bitshift(uint32(re_hex), 16), uint32(im_hex));
    fwrite(fid, word32, 'uint32');
end
fclose(fid);

%% ================= 4. Verification ================= %%
fft_sim_float = (dout_re + 1j * dout_im) / 2^FL_data;
mse = mean(abs(fft_ref - fft_sim_float).^2);
mse_db = 10 * log10(mse);
sqnr = 10 * log10(mean(abs(fft_ref).^2)/mse);
fprintf('Senario: %s\n', senario_name)
fprintf('Result N=%d (WL=%d, FL=%d)\n', N, WL, FL_data);
fprintf('MSE  : %.2f dB\n', mse_db);
fprintf('SQNR : %.2f dB\n', sqnr);


%% ================= ROM file Export ================= %%
% for i = 1:num_stages
%     file_name = sprintf('twiddle_ROM_%d.hex', i); 
%     fid = fopen(file_name, 'w'); 
%     for j = 1:N 
%         re_val = rom_buf_re(i, j);
%         im_val = rom_buf_im(i, j);
%         re_hex = bitand(int32(re_val), 2^WL-1); 
%         im_hex = bitand(int32(im_val), 2^WL-1);
%         fprintf(fid, '%04X%04X\n', re_hex, im_hex);
%     end
%     fclose(fid);
%     fprintf('Saved ROM Stage %d to %s\n', i, file_name);
% end

%% ================= Quantizaiton ================= %%
function int_val = quantization(val, total_bits, frac_bits)
    limit_max = 2^(total_bits-1) - 1;
    limit_min = -2^(total_bits-1);
    scaled = round(val * 2^frac_bits); 
    if scaled > limit_max, int_val = limit_max;
    elseif scaled < limit_min, int_val = limit_min;
    else, int_val = scaled; 
    end
end

%% ================= Hardward Modeling ================= %%
function [s_re, s_im, d_re, d_im] = butterfly(a_re, a_im, b_re, b_im)
    ia_re = int32(a_re);
    ia_im = int32(a_im);
    ib_re = int32(b_re);
    ib_im = int32(b_im);

    sum_re = ia_re + ib_re;
    sum_im = ia_im + ib_im;
    diff_re = ia_re - ib_re;
    diff_im = ia_im - ib_im;

    % truncation
    s_re = double(bitsra(sum_re, 1));
    s_im = double(bitsra(sum_im, 1));
    d_re = double(bitsra(diff_re, 1));
    d_im = double(bitsra(diff_im, 1));
end

function [o_re, o_im, w_re_out, w_im_out] = complex_mult(d_re, d_im, angle, t_frac, wl)
    limit_max = 2^(wl-1) - 1; 
    limit_min = -2^(wl-1);
    
    w_re_val = round(cos(angle) * 2^t_frac); 
    w_im_val = round(sin(angle) * 2^t_frac);
    
    w_re_int = int32(max(min(w_re_val, limit_max), limit_min));
    w_im_int = int32(max(min(w_im_val, limit_max), limit_min));
    
    i_re = int32(d_re);
    i_im = int32(d_im);
    
    ac = i_re * w_re_int;
    bd = i_im * w_im_int;
    ad = i_re * w_im_int;
    bc = i_im * w_re_int;
    
    real_mult = ac - bd;
    imag_mult = ad + bc;
    
    o_re_int = bitsra(real_mult, t_frac); 
    o_im_int = bitsra(imag_mult, t_frac);
    
    o_re = double(o_re_int);
    o_im = double(o_im_int);
    w_re_out = double(w_re_int);
    w_im_out = double(w_im_int);
end
