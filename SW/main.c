#include <stdio.h>
#include "xaxidma.h"
#include "xparameters.h"
#include "xil_printf.h"
#include "xscugic.h"
#include "input_data.h"
#include "output_data.h"


#define DMA_DEV_ID        	XPAR_AXIDMA_0_DEVICE_ID                           // DMA Device ID
#define INT_DEVICE_ID     	XPAR_SCUGIC_SINGLE_DEVICE_ID                      // Interrupt Controller Device ID
#define INTR_ID           	XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR           // DMA Interrupt ID
#define FFT_CTRL_BASEADDR   XPAR_FFT_TOP_0_BASEADDR

#define POINT 512
#define FIFO_DATABYTE   4
#define TEST_START_VALUE 0xC
#define NUMBER_OF_TRANSFERS 2
#define MAX_PKT_LEN POINT*FIFO_DATABYTE  // DMA Data Transfer Byte
/*
 * Function declaration
 */
int XAxiDma_Setup_Init(u16 DeviceId);
int XAxiDma_Setup(u16 DeviceId);
static int CheckData(void);
int SetInterruptInit(XScuGic *InstancePtr, u16 IntrID, XAxiDma *XAxiDmaPtr) ;

XScuGic INST ;   // Interrupt Controller Instance

XAxiDma AxiDma;  // Instance of the XAxiDma

u32 TxBufferPtr[MAX_PKT_LEN*NUMBER_OF_TRANSFERS] __attribute__ ((aligned(32)));
u32 RxBufferPtr[MAX_PKT_LEN*NUMBER_OF_TRANSFERS] __attribute__ ((aligned(32)));

u32 *selected_input = NULL;      // �쁽�옱 �쟾�넚�븷 �뜲�씠�꽣 二쇱냼
u32 *current_gold_data = NULL;   // 鍮꾧탳�븷 怨⑤뱺 �뜲�씠�꽣 二쇱냼
char *current_senario_name = "";
int current_point = 0;


int main()
{
    int Status;
    int point_val;
    int is_inverse;
    int ctrl_val;
    int senario_idx;
    Status = XAxiDma_Setup_Init(DMA_DEV_ID);

    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    xil_printf("\r\n==================================================\r\n");
    xil_printf(">> SoC_Design FFT Term Project 2022742020 AJY\r\n");
    xil_printf("==================================================\r\n");
    printf("Select Point (2, 4, 8, 16, 32, 64, 128, 256, 512, 1024): \n");
    scanf("%d", &point_val);
    current_point = point_val;
    printf("IFFT(1) or FFT(0)): \n");
    scanf("%d", &is_inverse);
    printf("Select Input Senario\n");
    printf("1. Impulse\n");
    printf("2. Constant\n");
    printf("3. Tone 4\n");
    printf("4. Normalized Random\n");
    scanf("%d", &senario_idx);

    // AXI4-Lite Data Setup
    ctrl_val = (is_inverse << 11) | point_val;
    Xil_Out32(FFT_CTRL_BASEADDR, ctrl_val);

    if(is_inverse) {
        selected_input = (u32*)FFT_input_tone4_inverse_1024_Data; 
        current_gold_data = (u32*)FFT_Output_tone4_inverse_1024_Data;
    }
    switch(senario_idx) {
    case 1: // Impulse
        current_senario_name = "Impulse";
        switch(point_val) {
            case 1024: selected_input = (u32*)FFT_input_impulse_1024_Data; current_gold_data = (u32*)FFT_Output_impulse_1024_Data; break;
            default:   printf("Invalid Point for Impulse\n"); break;
        }
        break;

    case 2: // Constant
        current_senario_name = "Constant";
        switch(point_val) {
            case 1024: selected_input = (u32*)FFT_input_constant_1024_Data; current_gold_data = (u32*)FFT_Output_constant_1024_Data; break;
            default:   printf("Invalid Point for Constant\n"); break;
        }
        break;

    case 3: // Tone 4
        current_senario_name = "Tone 4";
        switch(point_val) {
            case 1024: selected_input = (u32*)FFT_input_tone4_1024_Data; current_gold_data = (u32*)FFT_Output_tone4_1024_Data; break;
            default:   printf("Invalid Point for Tone 4\n"); break;
        }
        break;

    case 4: // Random
        current_senario_name = "Random";
        switch(point_val) {
            case 2:    selected_input = (u32*)FFT_input_random_2_Data;    current_gold_data = (u32*)FFT_Output_random_2_Data;    break;
            case 4:    selected_input = (u32*)FFT_input_random_4_Data;    current_gold_data = (u32*)FFT_Output_random_4_Data;    break;
            case 8:    selected_input = (u32*)FFT_input_random_8_Data;    current_gold_data = (u32*)FFT_Output_random_8_Data;    break;
            case 16:   selected_input = (u32*)FFT_input_random_16_Data;   current_gold_data = (u32*)FFT_Output_random_16_Data;   break;
            case 32:   selected_input = (u32*)FFT_input_random_32_Data;   current_gold_data = (u32*)FFT_Output_random_32_Data;   break;
            case 64:   selected_input = (u32*)FFT_input_random_64_Data;   current_gold_data = (u32*)FFT_Output_random_64_Data;   break;
            case 128:  selected_input = (u32*)FFT_input_random_128_Data;  current_gold_data = (u32*)FFT_Output_random_128_Data;  break;
            case 256:  selected_input = (u32*)FFT_input_random_256_Data;  current_gold_data = (u32*)FFT_Output_random_256_Data;  break;
            case 512:  selected_input = (u32*)FFT_input_random_512_Data;  current_gold_data = (u32*)FFT_Output_random_512_Data;  break;
            case 1024: selected_input = (u32*)FFT_input_random_1024_Data; current_gold_data = (u32*)FFT_Output_random_1024_Data; break;
        default:   printf("Invalid Point for Random\n"); break;
    }
        break;

    default:
        printf("Error: Invalid Scenario Selected.\n");
        break;
    }

    Status = XAxiDma_Setup(DMA_DEV_ID);  // DMA Setup & test function call

    if (Status != XST_SUCCESS) {
        xil_printf("XAxiDma Test Failed\r\n");
        return XST_FAILURE;
    }

    xil_printf("Successfully Ran XAxiDma Test\r\n");
    xil_printf("--- Exiting main() --- \r\n");
}



int SetInterruptInit(XScuGic *InstancePtr, u16 IntrID, XAxiDma *XAxiDmaPtr)
{

    XScuGic_Config * Config ;
    int Status ;

    Config = XScuGic_LookupConfig(INT_DEVICE_ID) ;

    Status = XScuGic_CfgInitialize(&INST, Config, Config->CpuBaseAddress) ;
    if (Status != XST_SUCCESS)
    return XST_FAILURE ;

    Status = XScuGic_Connect(InstancePtr, IntrID, (Xil_ExceptionHandler)CheckData, XAxiDmaPtr);

    if (Status != XST_SUCCESS) {
        return Status;
    }

    XScuGic_Enable(InstancePtr, IntrID) ;

    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler) XScuGic_InterruptHandler, InstancePtr);
    Xil_ExceptionEnable();
    return XST_SUCCESS ;
}


int XAxiDma_Setup(u16 DeviceId)
{
    XAxiDma_Config *CfgPtr;
    int Status;
    int Index;
    // 전체 전송할 바이트 계산 (1포인트당 4바이트 * 포인트 수 * 전송 횟수)
    int TotalByteLen = current_point * 4 * NUMBER_OF_TRANSFERS;

    /* 1. DMA 장치 설정 초기화 */
    CfgPtr = XAxiDma_LookupConfig(DeviceId);
    if (!CfgPtr) {
        xil_printf("No config found for %d\r\n", DeviceId);
        return XST_FAILURE;
    }

    Status = XAxiDma_CfgInitialize(&AxiDma, CfgPtr);
    if (Status != XST_SUCCESS) {
        xil_printf("Initialization failed %d\r\n", Status);
        return XST_FAILURE;
    }

    /* 2. Scatter Gather 모드 체크 */
    if(XAxiDma_HasSg(&AxiDma)){
        xil_printf("Device configured as SG mode \r\n");
        return XST_FAILURE;
    }

    /* 3. 인터럽트 설정 (S2MM 활성화, MM2S 비활성화) */
    XAxiDma_IntrEnable(&AxiDma, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

    /* 4. 전송 데이터 준비 (TxBuffer에 데이터 채우기) */
    // 입력 데이터를 전체 전송 횟수만큼 반복해서 TxBuffer에 채웁니다.
    for(int n = 0; n < NUMBER_OF_TRANSFERS; n++) {
        for(Index = 0; Index < current_point; Index++) {
            TxBufferPtr[n * current_point + Index] = selected_input[Index];
        }
    }

    /* 5. 데이터 캐시 플러시 (DRAM과 동기화) */
    Xil_DCacheFlushRange((UINTPTR)TxBufferPtr, TotalByteLen);
    Xil_DCacheFlushRange((UINTPTR)RxBufferPtr, TotalByteLen);

    /* 6. 전체 데이터 일괄 전송 시작 */
    // MM2S (Memory -> Device)
    Status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)TxBufferPtr, TotalByteLen, XAXIDMA_DMA_TO_DEVICE);
    if (Status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    // S2MM (Device -> Memory)
    Status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)RxBufferPtr, TotalByteLen, XAXIDMA_DEVICE_TO_DMA);
    if (Status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    /* 7. DMA 동작 완료 대기 (Polling) */
    while ((XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA)) || (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE))) {
        /* Wait until both transfers are done */
    }

    return XST_SUCCESS;
}


static int CheckData(void)
{
    u32 *RxPacket;
    int Index = 0;
    int Error = 0;
    RxPacket = RxBufferPtr;

    xil_printf("Enter Interrupt\r\n");
    /*Clear Interrupt*/
    XAxiDma_IntrAckIrq(&AxiDma, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA) ;
    /* Invalidate the DestBuffer before receiving the data, in case the
    * Data Cache is enabled
    */
    Xil_DCacheInvalidateRange((UINTPTR)RxPacket, current_point * 4 * NUMBER_OF_TRANSFERS);


    xil_printf("\r\n--- [ERROR ANALYSIS START] ---\r\n");
    xil_printf("Index | HW Value (R, I) | GD Value (R, I) | Status\r\n");
    xil_printf("----------------------------------------------------------\r\n");

    for(Index = 0; Index < (current_point * NUMBER_OF_TRANSFERS); Index++) {
        u32 hw_val = RxPacket[Index];
        u32 gold_val = current_gold_data[Index % current_point];

        // 실수(Real)와 허수(Imag) 성분 분리 (16-bit signed)
        short hw_re = (short)((hw_val >> 16) & 0xFFFF);
        short hw_im = (short)(hw_val & 0xFFFF);
        short gd_re = (short)((gold_val >> 16) & 0xFFFF);
        short gd_im = (short)(gold_val & 0xFFFF);

        if (hw_val != gold_val) {

            xil_printf("[%4d] | %08x (%5d, %5d) | %08x (%5d, %5d) | [MISMATCH]\r\n", 
                       Index, hw_val, hw_re, hw_im, gold_val, gd_re, gd_im);
            Error++;
        } else {
            // xil_printf("[%4d] | %08x (%5d, %5d) | %08x (%5d, %5d) | [  OK  ]\r\n", Index, hw_val, hw_re, hw_im, gold_val, gd_re, gd_im);
        }
    }

    xil_printf("----------------------------------------------------------\r\n");

    if(Error == 0) {
        xil_printf(">> Result: SUCCESS! All %d points matched.\r\n", Index);
    } else {
        xil_printf(">> Result: FAILURE! Total %d errors detected in %d points.\r\n", Error, Index);
    }
    xil_printf("--- [ERROR ANALYSIS END] ---\r\n");

    return XST_SUCCESS;
}

int XAxiDma_Setup_Init(u16 DeviceId) {
    XAxiDma_Config *CfgPtr;
    int Status;

    /* 1. DMA 하드웨어 설정 정보 찾기 */
    CfgPtr = XAxiDma_LookupConfig(DeviceId);
    if (!CfgPtr) {
        xil_printf("No config found for %d\r\n", DeviceId);
        return XST_FAILURE;
    }

    /* 2. DMA 객체 초기화 */
    Status = XAxiDma_CfgInitialize(&AxiDma, CfgPtr);
    if (Status != XST_SUCCESS) {
        xil_printf("Initialization failed %d\r\n", Status);
        return XST_FAILURE;
    }

    /* 3. Scatter Gather 모드 사용 여부 체크 (Simple 모드여야 함) */
    if(XAxiDma_HasSg(&AxiDma)){
        xil_printf("Device configured as SG mode \r\n");
        return XST_FAILURE;
    }

    /* 4. 인터럽트 컨트롤러 설정 및 연결 (중요: 여기서 ISR 등록됨) */
    Status = SetInterruptInit(&INST, INTR_ID, &AxiDma);
    if (Status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    /* 5. DMA 인터럽트 활성화 (S2MM: 하드웨어->메모리 완료 시 발생) */
    XAxiDma_IntrEnable(&AxiDma, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

    return XST_SUCCESS;
}
