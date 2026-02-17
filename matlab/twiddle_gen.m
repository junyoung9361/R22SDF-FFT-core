clear all; clc;
WL = 16;
FL = 15;
N = 256;

k = 0 : N-1;
data_complex = exp(-1i * 2 * pi * k / N);

% 1. 양자화 (Scaling & Rounding)
q_re = round(real(data_complex) * (2^FL));
q_im = round(imag(data_complex) * (2^FL));

limit_max = 2^(WL-1) - 1;
limit_min = -2^(WL-1);
q_re(q_re > limit_max) = limit_max;
q_re(q_re < limit_min) = limit_min;
q_im(q_im > limit_max) = limit_max;
q_im(q_im < limit_min) = limit_min;

% 3. Unsigned 변환 및 패킹
re_hex = uint32(bitand(int32(q_re), 65535));
im_hex = uint32(bitand(int32(q_im), 65535));
packed_data = bitshift(re_hex, 16) + im_hex;

% 4. .hex 파일 저장
fid = fopen('twiddle_ROM_2.hex', 'w');
for i = 1:N
    fprintf(fid, '%08X\n', packed_data(i));
end
fclose(fid);

disp('수학적으로 올바른 Twiddle Factor ROM 파일 생성이 완료되었습니다.');