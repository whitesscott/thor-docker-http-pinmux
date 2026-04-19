Attribute VB_Name = "Defined_Variables"
'
' Copyright (c) 2014, NVIDIA CORPORATION. All rights reserved.
'
' NVIDIA CORPORATION and its licensors retain all intellectual property
' and proprietary rights in and to this software and related documentation
' and any modifications thereto. Any use, reproduction, disclosure or
' distribution orf this software and related documentation without an express
' license agreement from NVIDIA CORPORATIOn is strictly prohibited.
'

' Const Variable
Public Const INVALID = "INVALID"

' Return Values
Public Enum ErrorValues
    SUCCESS = 0
    ERR_SANITY = -1
    ERR_FILEIO = -2
    ERR_PINTYPE = -3
    ERR_PULL = -4
    ERR_TRISTATE = -5
    ERR_E_INPUT = -6
    ERR_OD = -7
    ERR_LOCK = -8
    ERR_RCV_SEL = -9
    ERR_EMPTY_NAME = -10
    ERR_WRONG_GPIO_INIT = -11
    ERR_LPDR = -12
    ERR_EQOS = -13
End Enum

' Named Ranges
Public Const RANGE_CONFIG_FIRST = "ConfigFirstCell"
Public Const RANGE_CONFIG_LAST = "ConfigLastCell"
Public Const RANGE_FIRST_MPIO = "FirstMPIO"
Public Const RANGE_LAST_MPIO = "LastMPIO"
Public Const RANGE_PINGROUP = "Pin_Group"
Public Const RANGE_PUPD = "PUPD"
Public Const RANGE_TRISTATE = "Tristate"
Public Const RANGE_E_INPUT = "E_Input"
Public Const RANGE_ERROR_CHECK = "Error_Check"
Public Const RANGE_GPIO_INIT_VALUE = "GPIO_Init_Value"
Public Const RANGE_PIN_DIRECTION = "Pin_Direction"
Public Const RANGE_LOCK = "Lock"
Public Const RANGE_CUSTOMER_USAGE = "Customer_Usage"
Public Const RANGE_FIRST_PINMUXING_OPTION = "FirstPinMuxingOption"
Public Const RANGE_FIRST_PINGROUP = "FirstPinGroup"
Public Const RANGE_FUNCTION_0 = "Function_0"
Public Const RANGE_FUNCTION_SAFE = "Function_Safe"
Public Const RANGE_EXT_PU = "Ext_Pull_Up"
Public Const RANGE_EXT_PD = "Ext_Pull_Down"
Public Const RANGE_INITIAL_STATE = "Initial_State"
Public Const RANGE_WAKE_PIN = "Wake_Pin"
Public Const RANGE_PINMUX_UNUSED = "Pinmux_Unused"
Public Const RANGE_PINMUX_GPIO = "Pinmux_GPIO"
Public Const RANGE_PINMUX_SFIO0 = "Pinmux_SFIO0"
Public Const RANGE_PINMUX_SFIO1 = "Pinmux_SFIO1"
Public Const RANGE_PINMUX_SFIO2 = "Pinmux_SFIO2"
Public Const RANGE_PINMUX_SFIO3 = "Pinmux_SFIO3"
Public Const RANGE_ALLOWED_PIN_DIRECTION_GPIO = "AllowedPinDirection_GPIO"
Public Const RANGE_ALLOWED_PIN_DIRECTION_SFIO0 = "AllowedPinDirection_SFIO0"
Public Const RANGE_ALLOWED_PIN_DIRECTION_SFIO1 = "AllowedPinDirection_SFIO1"
Public Const RANGE_ALLOWED_PIN_DIRECTION_SFIO2 = "AllowedPinDirection_SFIO2"
Public Const RANGE_ALLOWED_PIN_DIRECTION_SFIO3 = "AllowedPinDirection_SFIO3"
Public Const RANGE_BOOTDEVICE = "BootDevice"
Public Const RANGE_PART_OF_BOOT_INTERFACE = "PartOfBootInterface"
Public Const RANGE_BOOT_INTERFACE = "BootInterface"
Public Const RANGE_BOOT_INTERFACE_CONFIG = "BootInterfaceConfig"
Public Const RANGE_RCV_SEL = "RCV_SEL"
Public Const RANGE_CUSTOMER_USAGE_CHECKER = "Customer_Usage_Checker"
Public Const RANGE_INITIAL_STATE_CHECKER = "Initial_State_Checker"
Public Const RANGE_PIN_DIRECTION_CHECKER = "Pin_Direction_Checker"
Public Const RANGE_RESISTOR_CHECKER = "Resistor_Checker"
Public Const RANGE_BOOT_INTERFACE_CHECKER = "Boot_Config_Checker"
Public Const RANGE_WAKE_CHECKER = "Wake_Checker"
Public Const RANGE_RCV_SEL_CHECKER = "RCV_SEL_Checker"
Public Const RANGE_MPIONAME = "MPIOName"
Public Const RANGE_FIRST_PADVOLTAGECONFIG = "FirstPadVoltageConfig"
Public Const RANGE_LAST_PADVOLTAGECONFIG = "LastPadVoltageConfig"
Public Const RANGE_PADVOLTAGECONFIG = "PadVoltageConfig"
Public Const RANGE_LPDR = "LPDR_Enable"
Public Const RANGE_EQOS = "EQOS_LPBK_Enable"
Public Const REVISION_NO = "REVISION_NUMBER"

