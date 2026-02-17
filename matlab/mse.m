%% ================= 1. Load All Data ================= %%
% 하드웨어에 들어갔던 입력값 (Fixed-point)
input_raw = load('input_x.txt'); 
% 하드웨어에서 나온 출력값 (Fixed-point)
output_raw = load('hw_out.txt'); 

%% ================= 2. Normalize (Fixed to Float) ================= %%
N = 1024;
WL = 16;
FL_data = 11; % 설계하신 소수점 비트 수

% 입력 데이터를 부동소수점으로 변환하여 Reference 계산용으로 사용
x_in_fixed = input_raw(:,1) + 1j*input_raw(:,2);
x_in_float = x_in_fixed / 2^FL_data; 

% 하드웨어 출력 데이터를 부동소수점으로 변환
dout_re = output_raw(:,1);
dout_im = output_raw(:,2);
fft_sim_float = (dout_re + 1j * dout_im) / 2^FL_data;

%% ================= 3. Ideal Reference (Double) ================= %%
% 하드웨어에 들어간 것과 "완전히 동일한" 입력으로 MATLAB FFT 수행
fft_ref = fft(x_in_float, N); 

%% ================= 4. Verification (MSE / SQNR) ================= %%
mse = mean(abs(fft_ref - fft_sim_float).^2);
mse_db = 10 * log10(mse);
sqnr = 10 * log10(mean(abs(fft_ref).^2)/mse);

fprintf('Result N=%d (WL=%d, FL=%d)\n', N, WL, FL_data);
fprintf('MSE   : %.2f dB\n', mse_db);
fprintf('SQNR  : %.2f dB\n', sqnr);

%% ================= 5. Plotting ================= %%
figure;
t = 0:N-1;
subplot(2,1,1);
plot(t, abs(fft_ref), 'b', 'LineWidth', 1.5); hold on;
plot(t, abs(fft_sim_float), 'r--', 'LineWidth', 1);
title(['Magnitude Comparison (SQNR: ', num2str(sqnr, '%.2f'), ' dB)']);
legend('MATLAB Ideal', 'Hardware Fixed');
grid on;

subplot(2,1,2);
plot(t, abs(fft_ref - fft_sim_float));
title('Absolute Error');
grid on;