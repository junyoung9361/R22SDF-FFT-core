clear all;
close all;
clc;

%% ================= 1. Parameter Setting ================= %%
N = 1024;             
total_stages = log2(N);

SCENARIO = 5
% input data Scenario Selection
switch SCENARIO
    case 1 % Impulse
        din_re_float = zeros(1, N);
        din_im_float = zeros(1, N);
        din_re_float(1) = 0.99;
    case 2 % Constant (DC)
        din_re_float = 0.5 * ones(1, N);
        din_im_float = 0.2 * ones(1, N);
    case 3 % Tone 4 Frequencies
        t = 0: N-1;
        freqs = [8, 32, 64, 128];
        sig_Sum = 0;
        for f = freqs
            sig_Sum = sig_Sum + 0.2 * exp(1j * 2 * pi * f * t / N);
        end
        din_re_float = real(sig_Sum);
        din_im_float = imag(sig_Sum);
    case 4 % Normalize Input
        scale_factor = 0.3;
        din_re_float = scale_factor * randn(1, N);
        din_im_float = scale_factor * randn(1, N);
    case 5 % Fixed Random
        rng(777);
        scale_factor = 8;
        din_re_float = scale_factor * randn(1, N);
        din_im_float = scale_factor * randn(1, N);
    otherwise
        error('Invalid Scenario Selected');
end

% Reference FFT (Matches HW scaling: FFT / N)
fft_ref = fft(din_re_float + 1j * din_im_float) / N;

curr_re = din_re_float; 
curr_im = din_im_float;

%% ================= 2. R2^2SDF FFT ================= %%
stages_processed = 0;

% if need RADIX2 stage
if mod(total_stages, 2) == 1
    M = N;
    D = M / 2;
    for k = 0 : D - 1
        idx_a = k + 1; idx_b = k + D + 1;
        
        [sum_re, sum_im, diff_re, diff_im] = butterfly_float(curr_re(idx_a), curr_im(idx_a), curr_re(idx_b), curr_im(idx_b));
        
        angle = -2 * pi * k / M;
        [mul_re, mul_im] = complex_mult_float(diff_re, diff_im, angle);
        
        curr_re(idx_a) = sum_re;
        curr_im(idx_a) = sum_im;
        curr_re(idx_b) = mul_re;
        curr_im(idx_b) = mul_im;
    end
    stages_processed = 1;
end

% Radix2^2 Block stage
num_macros = (total_stages - stages_processed) / 2;
current_N = N / (2^stages_processed); 

for m = 1 : num_macros
    M = current_N;
    
    % --- BF1 ---
    M1 = M; D1 = M1 / 2; num_groups_1 = N / M1;
    for g = 0 : num_groups_1 - 1
        offset = g * M1;
        for k = 0 : D1 - 1
            idx_a = offset + k + 1;
            idx_b = offset + k + D1 + 1;
            [sum_re, sum_im, diff_re, diff_im] = butterfly_float(curr_re(idx_a), curr_im(idx_a), curr_re(idx_b), curr_im(idx_b));
            curr_re(idx_a) = sum_re;
            curr_im(idx_a) = sum_im;
            curr_re(idx_b) = diff_re;
            curr_im(idx_b) = diff_im;
        end
    end
    
    % --- Trivial (-j) ---
    for g = 0 : num_groups_1 - 1
        offset = g * M1;
        for k = D1/2 : D1 - 1
            idx = offset + k + D1 + 1;
            re_val = curr_re(idx);
            im_val = curr_im(idx);
            curr_re(idx) = im_val;
            curr_im(idx) = -re_val;
        end
    end
    
    % --- BF2 ---
    M2 = M1 / 2;
    D2 = M2 / 2;
    num_groups_2 = N / M2;
    for g = 0 : num_groups_2 - 1
        offset = g * M2;
        for k = 0 : D2 - 1
            idx_a = offset + k + 1; idx_b = offset + k + D2 + 1;
            [sum_re, sum_im, diff_re, diff_im] = butterfly_float(curr_re(idx_a), curr_im(idx_a), curr_re(idx_b), curr_im(idx_b));
            curr_re(idx_a) = sum_re;
            curr_im(idx_a) = sum_im;
            curr_re(idx_b) = diff_re;
            curr_im(idx_b) = diff_im;
        end
    end
    
    % --- Complex Mult ---
    if m ~= num_macros
        D_twid = M / 4; num_groups_twid = N / M;
        for g = 0 : num_groups_twid - 1
            base = g * M;
            for k = 0 : D_twid - 1
                idx1 = base + k + D_twid + 1;      
                idx2 = base + k + 2*D_twid + 1;    
                idx3 = base + k + 3*D_twid + 1;
                
                angle = -2*pi*(2*k)/M;
                [curr_re(idx1), curr_im(idx1)] = complex_mult_float(curr_re(idx1), curr_im(idx1), angle);
                
                angle = -2*pi*k/M;
                [curr_re(idx2), curr_im(idx2)] = complex_mult_float(curr_re(idx2), curr_im(idx2), angle);
                    
                angle = -2*pi*(3*k)/M;
                [curr_re(idx3), curr_im(idx3)] = complex_mult_float(curr_re(idx3), curr_im(idx3), angle);
            end
        end
    end
    current_N = current_N / 4;
end

%% ================= 3. Bit Reversal ================= %%
dout_re = zeros(1, N);
dout_im = zeros(1, N);
num_bits = log2(N);

for i = 0:N-1
    bin_str = dec2bin(i, num_bits);
    rev_str = reverse(bin_str);
    rev_idx = bin2dec(rev_str);
    
    dout_re(rev_idx + 1) = curr_re(i + 1);
    dout_im(rev_idx + 1) = curr_im(i + 1);
end

fft_sim_float = (dout_re + 1j * dout_im); 

% MSE Check
error = abs(fft_ref - fft_sim_float).^2;
mse = mean(error);
signal_power = mean(abs(fft_ref).^2);
mse_db = 10 * log10(mse / signal_power);
sqnr = 10 * log10(signal_power / mse);

fprintf('Result N=%d (Floating Point Golden Model)\n', N);
fprintf('MSE  : %.2f dB\n', mse_db);
fprintf('SQNR : %.2f dB\n', sqnr);


%% ================= Modeling Hardware Block (Floating Point) ================= %%
% Butterfly (Float with Scaling to match HW data flow)
function [s_re, s_im, d_re, d_im] = butterfly_float(a_re, a_im, b_re, b_im)
    % Scaling by 0.5 to match HW "Shift Right" behavior
    s_re = (a_re + b_re) * 0.5;
    s_im = (a_im + b_im) * 0.5;
    d_re = (a_re - b_re) * 0.5;
    d_im = (a_im - b_im) * 0.5;
end

% Complex Mult (Float ideal multiplication)
function [o_re, o_im] = complex_mult_float(d_re, d_im, angle)
    w_re = cos(angle); 
    w_im = sin(angle);
    
    % Multiplication (a+jb)(c+jd)
    ac = d_re * w_re;
    bd = d_im * w_im;
    ad = d_re * w_im;
    bc = d_im * w_re;
    
    % Output
    o_re = ac - bd;
    o_im = ad + bc;
end