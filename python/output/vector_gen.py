import os
import re

def convert_hex_to_unified_header(output_file="output_data.h"):
    # 현재 폴더에서 .hex 파일 리스트 가져오기
    hex_files = [f for f in os.listdir('.') if f.endswith('.hex')]
    
    if not hex_files:
        print("변환할 .hex 파일이 폴더에 없습니다.")
        return

    with open(output_file, 'w') as f_out:
        # 헤더 가드 작성
        f_out.write("#ifndef OUTPUT_DATA_H\n")
        f_out.write("#define OUTPUT_DATA_H\n\n")
        f_out.write("#include \"xil_types.h\"\n\n")

        for input_file in hex_files:
            # 파일명 분석 (예: output_data_tone_1024.hex -> scenario: tone, point: 1024)
            # 파일명이 'input_data_시나리오_포인트' 혹은 'output_data_시나리오_포인트'인 경우 대응
            name_parts = os.path.splitext(input_file)[0].split('_')
            
            # 규칙에 따라 이름 추출 (뒤에서 두 번째가 scenario, 마지막이 point라고 가정)
            if len(name_parts) >= 3:
                scenario = name_parts[-2]
                point = name_parts[-1]
                # 원하시는 이름 형식: FFT_Output_scenario_point_Data
                array_name = f"FFT_Output_{scenario}_{point}_Data"
            else:
                # 파일 형식이 다를 경우를 대비한 예외 처리
                array_name = f"FFT_Output_{os.path.splitext(input_file)[0]}_Data"

            with open(input_file, 'r') as f_in:
                raw_data = f_in.read().split()
            
            # 데이터 정제 (언더바 제거)
            hex_list = [item.replace('_', '') for item in raw_data if len(item.replace('_', '')) > 0]
            
            # 배열 정보 기록
            f_out.write(f"// Generated from: {input_file}\n")
            f_out.write(f"#define {array_name.upper()}_LEN {len(hex_list)}\n")
            f_out.write(f"u32 {array_name}[{len(hex_list)}] __attribute__ ((aligned(32))) = {{\n")

            for i, val in enumerate(hex_list):
                comma = "," if i < len(hex_list) - 1 else ""
                newline = "\n" if (i + 1) % 8 == 0 else ""
                f_out.write(f"    0x{val}{comma}{newline}")

            f_out.write("\n};\n\n")
        
        f_out.write("#endif\n")
        
    print(f"성공: {len(hex_files)}개의 벡터가 '{output_file}'에 통합 저장되었습니다.")

if __name__ == "__main__":
    convert_hex_to_unified_header()