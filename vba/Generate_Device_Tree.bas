Attribute VB_Name = "Generate_Device_Tree"
'2/24/2025 Syntax change to pinmux_dtsi
' Change GPIO DTSI syntax: Bug # 5090679
'
' Copyright (c) 2024, NVIDIA CORPORATION. All rights reserved.
'
' NVIDIA CORPORATION and its licensors retain all intellectual property
' and proprietary rights in and to this software and related documentation
' and any modifications thereto. Any use, reproduction, disclosure or
' distribution orf this software and related documentation without an express
' license agreement from NVIDIA CORPORATIOn is strictly prohibited.
'

Option Explicit

Const DoubleTab = vbTab & vbTab
Const TripleTab = vbTab & vbTab & vbTab
Const QuadTab = vbTab & vbTab & vbTab & vbTab
 
Const CopyRightMessage1 = _
    "/*" & vbNewLine & _
    " * SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved." & vbNewLine & _
    " * SPDX-License-Identifier: BSD-3-Clause" & vbNewLine & _
    " *" & vbNewLine & _
    " * Redistribution and use in source and binary forms, with or without" & vbNewLine & _
    " * modification, are permitted provided that the following conditions are met:" & vbNewLine & _
    " *" & vbNewLine & _
    " * 1. Redistributions of source code must retain the above copyright notice, this" & vbNewLine & _
    " * list of conditions and the following disclaimer." & vbNewLine & _
    " *" & vbNewLine & _
    " * 2. Redistributions in binary form must reproduce the above copyright notice," & vbNewLine & _
    " * this list of conditions and the following disclaimer in the documentation" & vbNewLine & _
    " * and/or other materials provided with the distribution." & vbNewLine & _
    " * " & vbNewLine & _
    " * 3. Neither the name of the copyright holder nor the names of its" & vbNewLine & _
    " * contributors may be used to endorse or promote products derived from" & vbNewLine & _
    " * this software without specific prior written permission." & vbNewLine & _
    " *"

Const CopyRightMessage2 = _
    " * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 'AS IS'" & vbNewLine & _
    " * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE" & vbNewLine & _
    " * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE" & vbNewLine & _
    " * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE" & vbNewLine & _
    " * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL" & vbNewLine & _
    " * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR" & vbNewLine & _
    " * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER" & vbNewLine & _
    " * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY," & vbNewLine & _
    " * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE" & vbNewLine & _
    " * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE." & vbNewLine & _
    " */"

Const PinmuxIncludeMessage = _
    "#include ""t264-pinctrl-tegra.h"""
    
Const PadVoltageIncludeMessage = _
    "#include ""./"
    
Const GPIOIncludeMessage = _
    "#include ""tegra264-gpio.h"""

' Ball Configuration
Enum BallConfig
    CFG_RCV_SEL = 1
    CFG_LOCK = 2
    CFG_OD = 4
    CFG_E_INPUT = 8
    CFG_TRISTATE = 16
    CFG_PULL_DOWN = 32
    CFG_PULL_UP = 64
    CFG_I2C = 128
    CFG_DDC = 256
'    CFG_HAS_LPDR = 512
'    CFG_LPDR = 1024
    CFG_HAS_EQOS = 2048
    CFG_EQOS = 4096
    CFG_DRV_1X = 512
'    CFG_DRV_2X = &H2000
    CFG_DEF_1X = 1024
'    CFG_DEF_2X = &H4000
    
End Enum

Function GetFirstRow()
    GetFirstRow = Range(RANGE_CONFIG_FIRST).Row
End Function

Function GetLastRow()
    GetLastRow = Range(RANGE_CONFIG_LAST).Row
End Function

Function GetUsage(ByRef RowNumber As Integer)
    GetUsage = Worksheets(ActiveSheet.Name).Cells(RowNumber, Range(RANGE_CONFIG_FIRST).Column).Value
End Function

Function SetType(ByRef ConfigBits As Integer, ByRef PinType As String)
    Dim NewConfigBits As Integer
    
    If PinType = "REG" Then
        NewConfigBits = ConfigBits And (Not CFG_I2C) And (Not CFG_DDC)
    ElseIf PinType = "I2C" Then
        NewConfigBits = (ConfigBits Or CFG_I2C) And (Not CFG_DDC)
    ElseIf PinType = "DDC" Then
        NewConfigBits = (ConfigBits And (Not CFG_I2C)) Or CFG_DDC
    Else
        NewConfigBits = ERR_PINTYPE
    End If
    
    SetType = NewConfigBits
End Function

Function GetType(ByRef ConfigBits As Integer)
    Dim CheckerNumber As Integer
    
    CheckerNumber = ConfigBits And (CFG_I2C Or CFG_DDC)
    CheckerNumber = (CheckerNumber \ CFG_I2C) Mod 4
    
    If CheckerNumber > 2 Then CheckerNumber = ERR_PINTYPE
    
    GetType = CheckerNumber
End Function

Function SetPull(ByRef ConfigBits As Integer, ByRef PUPD As String)
    Dim NewConfigBits As Integer
    
    If PUPD = "NORMAL" Then
        NewConfigBits = ConfigBits And (Not CFG_PULL_UP) And (Not CFG_PULL_DOWN)
    ElseIf PUPD = "PULL_DOWN" Then
        NewConfigBits = (ConfigBits And (Not CFG_PULL_UP)) Or CFG_PULL_DOWN
    ElseIf PUPD = "PULL_UP" Then
        NewConfigBits = (ConfigBits Or CFG_PULL_UP) And (Not CFG_PULL_DOWN)
    Else
        NewConfigBits = ERR_PULL
    End If
    
    SetPull = NewConfigBits
End Function

Function GetPull(ByRef ConfigBits As Integer)
    Dim CheckerNumber As Integer
    
    CheckerNumber = ConfigBits And (CFG_PULL_UP Or CFG_PULL_DOWN)
    CheckerNumber = (CheckerNumber \ CFG_PULL_DOWN) Mod 4
    
    If CheckerNumber > 2 Then CheckerNumber = ERR_PULL
    
    If CheckerNumber = 0 Then
        GetPull = "TEGRA_PIN_PULL_NONE"
    ElseIf CheckerNumber = 1 Then
        GetPull = "TEGRA_PIN_PULL_DOWN"
    ElseIf CheckerNumber = 2 Then
        GetPull = "TEGRA_PIN_PULL_UP"
    Else
        GetPull = CheckerNumber
    End If
End Function

Function SetTristate(ByRef ConfigBits As Integer, ByRef Tristate As String)
    Dim NewConfigBits As Integer
    
    If Tristate = "NORMAL" Then
        NewConfigBits = ConfigBits And (Not CFG_TRISTATE)
    ElseIf Tristate = "TRISTATE" Then
        NewConfigBits = ConfigBits Or CFG_TRISTATE
    Else
        NewConfigBits = ERR_TRISTATE
    End If
    
    SetTristate = NewConfigBits
End Function

Function GetTristate(ByRef ConfigBits As Integer)
    Dim CheckerNumber As Integer
    
    CheckerNumber = ConfigBits And CFG_TRISTATE
    CheckerNumber = (CheckerNumber \ CFG_TRISTATE) Mod 2
    
    If CheckerNumber = 0 Then
        GetTristate = "TEGRA_PIN_DISABLE"
    Else
        GetTristate = "TEGRA_PIN_ENABLE"
    End If
End Function

Function SetEInput(ByRef ConfigBits As Integer, ByRef EInput As String)
    Dim NewConfigBits As Integer
    
    If EInput = "DISABLE" Then
        NewConfigBits = ConfigBits And (Not CFG_E_INPUT)
    ElseIf EInput = "ENABLE" Then
        NewConfigBits = ConfigBits Or CFG_E_INPUT
    Else
        NewConfigBits = ERR_E_INPUT
    End If
    
    SetEInput = NewConfigBits
End Function

Function GetEInput(ByRef ConfigBits As Integer)
    Dim CheckerNumber As Integer
    
    CheckerNumber = ConfigBits And CFG_E_INPUT
    CheckerNumber = (CheckerNumber \ CFG_E_INPUT) Mod 2
    
    If CheckerNumber = 0 Then
        GetEInput = "TEGRA_PIN_DISABLE"
    Else
        GetEInput = "TEGRA_PIN_ENABLE"
    End If
End Function

Function SetOD(ByRef ConfigBits As Integer, ByRef OD As String)
    Dim NewConfigBits As Integer
    
    If OD = "ENABLE" Then
        NewConfigBits = ConfigBits Or CFG_OD
    Else
        NewConfigBits = ConfigBits And (Not CFG_OD)
    End If
    
    SetOD = NewConfigBits
End Function

Function GetOD(ByRef ConfigBits As Integer)
    Dim CheckerNumber As Integer
    
    CheckerNumber = ConfigBits And CFG_OD
    CheckerNumber = (CheckerNumber \ CFG_OD) Mod 2
    
    If CheckerNumber = 0 Then
        GetOD = "TEGRA_PIN_DISABLE"
    Else
        GetOD = "TEGRA_PIN_ENABLE"
    End If
End Function

Function SetLock(ByRef ConfigBits As Integer, ByRef LockED As String)
    Dim NewConfigBits As Integer
    
    'Workaround: If lock cell is empty, treat it as disable. However, it should be defined.
    If LockED = "Disable" Or LockED = "" Then
        NewConfigBits = ConfigBits And (Not CFG_LOCK)
    ElseIf LockED = "Enable" Then
        NewConfigBits = ConfigBits Or CFG_LOCK
    Else
        NewConfigBits = ERR_LOCK
    End If
    
    SetLock = NewConfigBits
End Function

Function GetLock(ByRef ConfigBits As Integer)
    Dim CheckerNumber As Integer
    
    CheckerNumber = ConfigBits And CFG_LOCK
    CheckerNumber = (CheckerNumber \ CFG_LOCK) Mod 2
    
    If CheckerNumber = 0 Then
        GetLock = "TEGRA_PIN_DISABLE"
    Else
        GetLock = "TEGRA_PIN_ENABLE"
    End If
End Function

Function SetRCVSEL(ByRef ConfigBits As Integer, ByRef RCVSEL As String)
    Dim NewConfigBits As Integer
    
    If RCVSEL = "DISABLE" Then
        NewConfigBits = ConfigBits And (Not CFG_RCV_SEL)
    ElseIf RCVSEL = "ENABLE" Then
        NewConfigBits = ConfigBits Or CFG_RCV_SEL
    Else
        NewConfigBits = ERR_RCV_SEL
    End If
    
    SetRCVSEL = NewConfigBits
End Function

Function GetRCVSEL(ByRef ConfigBits As Integer)
    Dim CheckerNumber As Integer
    
    CheckerNumber = ConfigBits And CFG_RCV_SEL
    CheckerNumber = (CheckerNumber \ CFG_RCV_SEL) Mod 2
    
    If CheckerNumber = 0 Then
        GetRCVSEL = "TEGRA_PIN_DISABLE"
    Else
        GetRCVSEL = "TEGRA_PIN_ENABLE"
    End If
End Function

' E_lpbk
Function SetELPBK(ByRef ConfigBits As Integer, ByRef ELPBK As String)
    Dim NewConfigBits As Integer
    
    If ELPBK = "DISABLE" Then
        NewConfigBits = ConfigBits And (Not CFG_E_LPBK)
    ElseIf ELPBK = "ENABLE" Then
        NewConfigBits = ConfigBits Or CFG_E_LPBK
    Else
        NewConfigBits = ERR_WRONG_E_LPBK
    End If
    
    SetELPBK = NewConfigBits
End Function

Function GetELPBK(ByRef ConfigBits As Integer)
    Dim CheckerNumber As Integer
    
    CheckerNumber = ConfigBits And CFG_E_LPBK
    CheckerNumber = (CheckerNumber \ CFG_E_LPBK) Mod 2
    
    If CheckerNumber = 0 Then
        GetELPBK = "TEGRA_PIN_DISABLE"
    Else
        GetELPBK = "TEGRA_PIN_ENABLE"
    End If
End Function

Function SetDDC(ByRef ConfigBits As Integer)
    Dim NewConfigBits As Integer
    
    NewConfigBits = ConfigBits Or CFG_DDC
    
    SetDDC = NewConfigBits
End Function

Function GetDDC(ByRef ConfigBits As Integer)
    Dim CheckerNumber As Integer
    
    CheckerNumber = ConfigBits And CFG_DDC
    CheckerNumber = (CheckerNumber \ CFG_DDC) Mod 2
    
    GetDDC = CheckerNumber
End Function

Function SetI2C(ByRef ConfigBits As Integer)
    Dim NewConfigBits As Integer
    
    NewConfigBits = ConfigBits Or CFG_I2C
    
    SetI2C = NewConfigBits
End Function

Function GetI2C(ByRef ConfigBits As Integer)
    Dim CheckerNumber As Integer
    
    CheckerNumber = ConfigBits And CFG_I2C
    CheckerNumber = (CheckerNumber \ CFG_I2C) Mod 2
    
    GetI2C = CheckerNumber
End Function

Function SetLPDR(ByRef ConfigBits As Integer, ByRef LPDR As String)
    Dim NewConfigBits As Integer
    
    If LPDR = "DISABLE" Then
        NewConfigBits = ConfigBits And (Not CFG_DEF_1X) And (Not CFG_DRV_1X)

    ElseIf LPDR = "ENABLE" Then
        NewConfigBits = (ConfigBits And (Not CFG_DEF_1X)) Or CFG_DRV_1X

    ElseIf LPDR = "DEF_1X" Then
        NewConfigBits = (ConfigBits Or CFG_DEF_1X) And (Not CFG_DRV_1X)

    ElseIf LPDR = "DEF_2X" Then
        NewConfigBits = ConfigBits Or CFG_DRV_1X Or CFG_DEF_1X

    Else
        NewConfigBits = ERR_LPDR
    End If
    
    SetLPDR = NewConfigBits
End Function

Function GetLPDR(ByRef ConfigBits As Integer)
    Dim CheckerNumber As Integer
    
    CheckerNumber = ConfigBits And (CFG_DRV_1X Or CFG_DEF_1X)
    CheckerNumber = (CheckerNumber \ CFG_DRV_1X) Mod 4

    If CheckerNumber > 3 Then CheckerNumber = ERR_LPDR
    
    If CheckerNumber = 0 Then
        GetLPDR = "TEGRA_PIN_1X_DRIVER"

    ElseIf CheckerNumber = 1 Then
        GetLPDR = "TEGRA_PIN_2X_DRIVER"

    ElseIf CheckerNumber = 2 Then
        GetLPDR = "TEGRA_PIN_DEFAULT_DRIVE_1X"

    ElseIf CheckerNumber = 3 Then
        GetLPDR = "TEGRA_PIN_DEFAULT_DRIVE_2X"

    Else
        GetLPDR = "TEGRA_PIN_COMP"
    End If
End Function

Function SetHasEQOS(ByRef ConfigBits As Integer)
    Dim NewConfigBits As Integer
    
    NewConfigBits = ConfigBits Or CFG_HAS_EQOS
    
    SetHasEQOS = NewConfigBits
End Function

Function GetHasEQOS(ByRef ConfigBits As Integer)
    Dim CheckerNumber As Integer
    
    CheckerNumber = ConfigBits And CFG_HAS_EQOS
    CheckerNumber = (CheckerNumber \ CFG_HAS_EQOS) Mod 2
    
    GetHasEQOS = CheckerNumber
End Function

Function SetEQOS(ByRef ConfigBits As Integer, ByRef EQOS As String)
    Dim NewConfigBits As Integer
    
    If EQOS = "DISABLE" Then
        NewConfigBits = ConfigBits And (Not CFG_EQOS)
    ElseIf EQOS = "ENABLE" Then
        NewConfigBits = ConfigBits Or CFG_EQOS
    Else
        NewConfigBits = ERR_EQOS
    End If
    
    SetEQOS = NewConfigBits
End Function

Function GetEQOS(ByRef ConfigBits As Integer)
    Dim CheckerNumber As Integer
    
    CheckerNumber = ConfigBits And CFG_EQOS
    CheckerNumber = (CheckerNumber \ CFG_EQOS) Mod 2
    
    If CheckerNumber = 0 Then
        GetEQOS = "TEGRA_PIN_DISABLE"
    Else
        GetEQOS = "TEGRA_PIN_ENABLE"
    End If
End Function

Function SanityCheck()
    Dim CurrentRow As Integer
    Dim CurrentColumn As Integer

    CurrentRow = GetFirstRow()

    ' Go through all pinmux configuration made by the customer and check if there's any invalid choice.
    Do While CurrentRow <= GetLastRow()
        CurrentColumn = Range(RANGE_CONFIG_FIRST).Column
        Do While CurrentColumn <= Range(RANGE_ERROR_CHECK).Column
            If Worksheets(ActiveSheet.Name).Cells(CurrentRow, CurrentColumn).Value = INVALID Then
                SanityCheck = ERR_SANITY
                Exit Function
            End If
            CurrentColumn = CurrentColumn + 1
        Loop
        CurrentRow = CurrentRow + 1
    Loop
    
    SanityCheck = SUCCESS
End Function

Function CountMPIO(ByRef MPIOCount As Integer, ByRef SFIOCount As Integer, ByRef GPIOCount As Integer, ByRef UnusedCount As Integer)
    Dim CurrentRow As Integer
    Dim CurrentVal As String
    Dim CurrentUsage As String
    
    CurrentRow = GetFirstRow()
    MPIOCount = 0
    SFIOCount = 0
    GPIOCount = 0
    UnusedCount = 0
    
    Do While CurrentRow <= GetLastRow()
        CurrentVal = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_CONFIG_FIRST).Column).Value
        If CurrentVal <> "" Then
            MPIOCount = MPIOCount + 1
            CurrentUsage = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_CUSTOMER_USAGE).Column).Value
            If InStr(1, CurrentUsage, "unused") Then
                UnusedCount = UnusedCount + 1
            ElseIf InStr(1, CurrentUsage, "GPIO3") Then
                GPIOCount = GPIOCount + 1
            Else
                SFIOCount = SFIOCount + 1
            End If
        End If
        CurrentRow = CurrentRow + 1
    Loop
    
    CountMPIO = SUCCESS
End Function

Function FillArrays(ByRef MPIOIndex() As Integer, ByRef MPIOName() As String, ByRef SFIOName() As String, ByRef GPIOName() As String, ByRef GPIOInitValue() As Integer, _
                ByRef MPIOConfigValue() As Integer, ByRef NumberOfSFIO As Integer, ByRef NumberOfGPIO As Integer, ByRef NumberOfUnused As Integer)
    Dim CurrentRow As Integer
    Dim CurrentVal As String
    Dim CurrentIndex As Integer
    Dim CurrentSFIOIndex As Integer
    Dim CurrentGPIOIndex As Integer
    Dim CurrentUnusedIndex As Integer
    Dim CurrentUsage As String
    Dim PortName As String
    Dim PortType As String
    Dim RetVal As Integer
    Dim USBCheck As Boolean
    Dim NumberOfMPIO As Integer
    Const AonListStr = "AABBCCDDEE"
    Const FsiListStr = "ABACADAEAFAGAHAJ"
    Const UphyListStr = "ABCDE"

    NumberOfMPIO = NumberOfSFIO + NumberOfGPIO + NumberOfUnused
    
    ReDim MPIOIndex(NumberOfMPIO) As Integer
    ReDim MPIOName(NumberOfMPIO) As String
    ReDim SFIOName(NumberOfMPIO) As String
    ReDim GPIOName(NumberOfMPIO) As String
    ReDim GPIOInitValue(NumberOfMPIO) As Integer
    ReDim MPIOConfigValue(NumberOfMPIO) As Integer
    
    CurrentRow = GetFirstRow()
    CurrentSFIOIndex = 1
    CurrentGPIOIndex = 1 + NumberOfSFIO
    CurrentUnusedIndex = 1 + NumberOfSFIO + NumberOfGPIO
        
    Do While CurrentRow <= GetLastRow()
        CurrentVal = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_CONFIG_FIRST).Column).Value
        'Initialize valid pin configuration
        If CurrentVal <> "" Then
            CurrentUsage = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_CUSTOMER_USAGE).Column).Value
            If InStr(1, CurrentUsage, "unused") Then
                CurrentIndex = CurrentUnusedIndex
                CurrentUnusedIndex = CurrentUnusedIndex + 1
            ElseIf InStr(1, CurrentUsage, "GPIO3") Then
                CurrentIndex = CurrentGPIOIndex
                CurrentGPIOIndex = CurrentGPIOIndex + 1
            Else
                CurrentIndex = CurrentSFIOIndex
                CurrentSFIOIndex = CurrentSFIOIndex + 1
            End If
            
            'Initialize valid pin index
            MPIOIndex(CurrentIndex) = CurrentRow
            
            'Initialize valid pin name for device tree
            'Changed method of acquiring MPIOName. MPIOName moved to a column in the spreadsheet
            MPIOName(CurrentIndex) = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_MPIONAME).Column).Value
            
            'Initialize GPIO names for DT
            CurrentVal = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_FIRST_PINMUXING_OPTION).Column).Value
            If CurrentVal <> "" Then
                PortName = UCase(Mid(CurrentVal, Len("GPIO3_P") + 1, Len(CurrentVal) - Len("GPIO3_P") - Len(".00")))
                If (InStr(FsiListStr, PortName) <> 0) And (Len(PortName) = 2) Then
                    PortType = "TEGRA264_FSI_GPIO("
                    
                ElseIf (InStr(AonListStr, PortName) <> 0) And (Len(PortName) = 2) Then
                    PortType = "TEGRA264_AON_GPIO("
                ElseIf (InStr(UphyListStr, PortName) <> 0) And (Len(PortName) = 1) Then
                    PortType = "TEGRA264_UPHY_GPIO("
                Else
                    PortType = "TEGRA264_MAIN_GPIO("
                End If
                
                GPIOName(CurrentIndex) = PortType & PortName & _
                                ", " & Right(CurrentVal, 1) & ")"
            End If
            
            'Initialize valid function name
            If InStr(1, CurrentUsage, "unused") Or InStr(1, CurrentUsage, "GPIO3") Then
                CurrentVal = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_FUNCTION_SAFE).Column).Value
            Else
                CurrentVal = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_CONFIG_FIRST).Column).Value
            End If
            SFIOName(CurrentIndex) = LCase(CurrentVal)
            
            'Initliaze valid pin configuration
            MPIOConfigValue(CurrentIndex) = 0
            
            'Pull Up/Down
            CurrentVal = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_PUPD).Column).Value
            RetVal = SetPull(MPIOConfigValue(CurrentIndex), CurrentVal)
            If RetVal < 0 Then GoTo FillArrays_Fail
            MPIOConfigValue(CurrentIndex) = RetVal
            
            'Tristate
            CurrentVal = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_TRISTATE).Column).Value
            RetVal = SetTristate(MPIOConfigValue(CurrentIndex), CurrentVal)
            If RetVal < 0 Then GoTo FillArrays_Fail
            MPIOConfigValue(CurrentIndex) = RetVal
            
            'E_input
            CurrentVal = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_E_INPUT).Column).Value
            RetVal = SetEInput(MPIOConfigValue(CurrentIndex), CurrentVal)
            If RetVal < 0 Then GoTo FillArrays_Fail
            MPIOConfigValue(CurrentIndex) = RetVal
            
            'GPIOInitVal
            CurrentVal = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_GPIO_INIT_VALUE).Column).Value
            If (CurrentVal = "N/A" Or CurrentVal = "") Then
                GPIOInitValue(CurrentIndex) = -1
            ElseIf (CurrentVal = "1") Then
                GPIOInitValue(CurrentIndex) = 1
            Else
                GPIOInitValue(CurrentIndex) = 0
            End If
            
            '3.3V Tolerance Enable/Disable
            CurrentVal = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_RCV_SEL).Column).Value
            If (CurrentVal <> "") Then
                MPIOConfigValue(CurrentIndex) = SetDDC(MPIOConfigValue(CurrentIndex))
                RetVal = SetRCVSEL(MPIOConfigValue(CurrentIndex), UCase(CurrentVal))
                If RetVal < 0 Then GoTo FillArrays_Fail
                MPIOConfigValue(CurrentIndex) = RetVal
            End If
            
            'OD
            CurrentVal = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_PIN_DIRECTION).Column).Value
            If (CurrentVal = "Open-Drain") Then
                RetVal = SetOD(MPIOConfigValue(CurrentIndex), "ENABLE")
                If RetVal < 0 Then GoTo FillArrays_Fail
                MPIOConfigValue(CurrentIndex) = RetVal
            End If
            
            'Lock
            CurrentVal = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_LOCK).Column).Value
            If (CurrentVal <> "") Then
                RetVal = SetLock(MPIOConfigValue(CurrentIndex), UCase(CurrentVal))
                If RetVal < 0 Then GoTo FillArrays_Fail
                MPIOConfigValue(CurrentIndex) = RetVal
            End If
            
            'LPDR Enable/Disable
            CurrentVal = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_LPDR).Column).Value
            If (CurrentVal <> "") Then
'                MPIOConfigValue(CurrentIndex) = SetHasLPDR(MPIOConfigValue(CurrentIndex))
                RetVal = SetLPDR(MPIOConfigValue(CurrentIndex), UCase(CurrentVal))
                If RetVal < 0 Then GoTo FillArrays_Fail
                MPIOConfigValue(CurrentIndex) = RetVal
            End If
            
            'EQOS LPBK Enable/Disable
            CurrentVal = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_EQOS).Column).Value
            If (CurrentVal <> "") Then
                MPIOConfigValue(CurrentIndex) = SetHasEQOS(MPIOConfigValue(CurrentIndex))
                RetVal = SetEQOS(MPIOConfigValue(CurrentIndex), UCase(CurrentVal))
                If RetVal < 0 Then GoTo FillArrays_Fail
                MPIOConfigValue(CurrentIndex) = RetVal
            End If
            
            CurrentIndex = CurrentIndex + 1
        End If
        CurrentRow = CurrentRow + 1
    Loop
    
    RetVal = SUCCESS
    
FillArrays_Fail:
    FillArrays = RetVal
End Function

Function GroupPins(ByRef MPIOIndex() As Integer, ByRef MPIOName() As String, ByRef SFIOName() As String, ByRef GPIOName() As String, ByRef GPIOInitValue() As Integer, _
                ByRef MPIOConfigValue() As Integer, ByRef NumberOfSFIO As Integer, ByRef NumberOfGPIO As Integer, ByRef NumberOfUnused As Integer)
    Dim RetVal As Integer
    
    RetVal = FillArrays(MPIOIndex, MPIOName, SFIOName, GPIOName, GPIOInitValue, MPIOConfigValue, NumberOfSFIO, NumberOfGPIO, NumberOfUnused)
    If RetVal < 0 Then GoTo GroupPins_Fail
      
GroupPins_Fail:
    GroupPins = RetVal
End Function

Function PrintPinmuxDT(ByRef Output As String, ByRef MPIOName() As String, ByRef SFIOName() As String, ByRef MPIOConfigValue() As Integer, _
                ByRef MaxSFIOIndex As Integer, ByRef MaxGPIOIndex As Integer, ByRef MaxUnusedIndex As Integer)
    Dim CurrentIndex As Integer
    Dim MaxUsedIndex As Integer
    Dim MaxIndex As Integer
    
    MaxUsedIndex = MaxSFIOIndex + MaxGPIOIndex
    MaxIndex = MaxUsedIndex + MaxUnusedIndex
    
    Output = DoubleTab & "common {" & vbNewLine
    Output = Output & TripleTab & "/* SFIO Pin Configuration */" & vbNewLine
    
    CurrentIndex = 1
    Do While CurrentIndex <= MaxUsedIndex
        Output = Output & TripleTab & MPIOName(CurrentIndex) & " {" & vbNewLine & _
                QuadTab & "nvidia,pins = " & Chr(34) & _
                MPIOName(CurrentIndex) & Chr(34)
        Output = Output & ";" & vbNewLine & QuadTab & _
                "nvidia,function = " & Chr(34) & SFIOName(CurrentIndex) & Chr(34) & ";" & _
                vbNewLine & QuadTab & _
                "nvidia,pull = <" & GetPull(MPIOConfigValue(CurrentIndex)) & ">;" & _
                vbNewLine & QuadTab & _
                "nvidia,tristate = <" & GetTristate(MPIOConfigValue(CurrentIndex)) & ">;" & _
                vbNewLine & QuadTab & _
                "nvidia,enable-input = <" & GetEInput(MPIOConfigValue(CurrentIndex)) & ">;" & _
                vbNewLine & QuadTab & _
                "nvidia,drv-type = <" & GetLPDR(MPIOConfigValue(CurrentIndex)) & ">;" & vbNewLine
        
        If (GetLock(MPIOConfigValue(CurrentIndex)) = "TEGRA_PIN_ENABLE") Then
            Output = Output & QuadTab & "nvidia,lock = <" & GetLock(MPIOConfigValue(CurrentIndex)) & ">;" & vbNewLine
        End If
        If (GetOD(MPIOConfigValue(CurrentIndex)) = "TEGRA_PIN_ENABLE") Then
            Output = Output & QuadTab & "nvidia,open-drain = <" & GetOD(MPIOConfigValue(CurrentIndex)) & ">;" & vbNewLine
        End If
        If GetDDC(MPIOConfigValue(CurrentIndex)) Then
            Output = Output & QuadTab & "nvidia,e-io-od = <" & GetRCVSEL(MPIOConfigValue(CurrentIndex)) & ">;" & vbNewLine
        End If
'        If GetHasLPDR(MPIOConfigValue(CurrentIndex)) Then
'            Output = Output & QuadTab & "nvidia,drv-type = <" & GetLPDR(MPIOConfigValue(CurrentIndex)) & ">;" & vbNewLine
'        End If
        If GetHasEQOS(MPIOConfigValue(CurrentIndex)) Then
            Output = Output & QuadTab & "nvidia,e-lpbk = <" & GetEQOS(MPIOConfigValue(CurrentIndex)) & ">;" & vbNewLine
        End If
        Output = Output & TripleTab & "};" & vbNewLine
        If CurrentIndex < MaxUsedIndex Then Output = Output & vbNewLine
        If CurrentIndex = MaxSFIOIndex Then Output = Output & TripleTab & "/* GPIO Pin Configuration */" & vbNewLine
        CurrentIndex = CurrentIndex + 1
    Loop
    
    Output = Output & DoubleTab & "};" & vbNewLine & vbNewLine
'   comment out below line 09/18/2024
'   Output = Output & DoubleTab & "pinmux_unused_lowpower: unused_lowpower {" & vbNewLine
    Output = Output & vbTab & "pinmux_unused_lowpower: unused_lowpower {" & vbNewLine
    Do While CurrentIndex <= MaxIndex
        Output = Output & TripleTab & MPIOName(CurrentIndex) & " {" & vbNewLine & _
                QuadTab & "nvidia,pins = " & Chr(34) & _
                MPIOName(CurrentIndex) & Chr(34)
        Output = Output & ";" & vbNewLine & QuadTab & _
                "nvidia,function = " & Chr(34) & SFIOName(CurrentIndex) & Chr(34) & ";" & _
                vbNewLine & QuadTab & _
                "nvidia,pull = <" & GetPull(MPIOConfigValue(CurrentIndex)) & ">;" & _
                vbNewLine & QuadTab & _
                "nvidia,tristate = <" & GetTristate(MPIOConfigValue(CurrentIndex)) & ">;" & _
                vbNewLine & QuadTab & _
                "nvidia,enable-input = <" & GetEInput(MPIOConfigValue(CurrentIndex)) & ">;" & _
                vbNewLine & QuadTab & _
                "nvidia,drv-type = <" & GetLPDR(MPIOConfigValue(CurrentIndex)) & ">;" & vbNewLine

        If (GetLock(MPIOConfigValue(CurrentIndex)) = "TEGRA_PIN_ENABLE") Then
            Output = Output & QuadTab & "nvidia,lock = <" & GetLock(MPIOConfigValue(CurrentIndex)) & ">;" & vbNewLine
        End If
        If (GetOD(MPIOConfigValue(CurrentIndex)) = "TEGRA_PIN_ENABLE") Then
            Output = Output & QuadTab & "nvidia,open-drain = <" & GetOD(MPIOConfigValue(CurrentIndex)) & ">;" & vbNewLine
        End If
        If GetDDC(MPIOConfigValue(CurrentIndex)) Then
            Output = Output & QuadTab & "nvidia,e-io-od = <" & GetRCVSEL(MPIOConfigValue(CurrentIndex)) & ">;" & vbNewLine
        End If
'        If GetHasLPDR(MPIOConfigValue(CurrentIndex)) Then
'            Output = Output & QuadTab & "nvidia,drv-type = <" & GetLPDR(MPIOConfigValue(CurrentIndex)) & ">;" & vbNewLine
'        End If
        If GetHasEQOS(MPIOConfigValue(CurrentIndex)) Then
            Output = Output & QuadTab & "nvidia,e-lpbk = <" & GetEQOS(MPIOConfigValue(CurrentIndex)) & ">;" & vbNewLine
        End If
        Output = Output & TripleTab & "};" & vbNewLine
        CurrentIndex = CurrentIndex + 1
        If CurrentIndex <= MaxIndex Then Output = Output & vbNewLine
    Loop
    
    Output = Output & DoubleTab & "};" & vbNewLine & vbNewLine
    Output = Output & DoubleTab & "drive_default: drive {" & vbNewLine

'    Output = Output & DriveStrength & vbNewLine
'    comment out below line 09/18/2024
    Output = Output & DoubleTab & "};"
End Function

Function PrintGPIODT(ByRef Output As String, ByRef GPIOType As String, ByRef GPIOName() As String, ByRef GPIOInitValue() As Integer, ByRef MPIOConfigValue() As Integer, _
                ByRef MaxSFIOIndex As Integer, ByRef MaxGPIOIndex As Integer, ByRef MaxUnusedIndex As Integer)
    Dim CurrentIndex As Integer
    Dim MaxUsedIndex As Integer
    Dim MaxIndex As Integer
    Dim InputGPIOs As String
    Dim OutputLowGPIOs As String
    Dim OutputHighGPIOs As String
    Dim Heading As String
    Dim RetVal As Integer
    
    MaxUsedIndex = MaxSFIOIndex + MaxGPIOIndex
    MaxIndex = MaxUsedIndex + MaxUnusedIndex
    RetVal = SUCCESS
    
    If GPIOType = "MAIN" Then
        Output = "gpio@ac300000 {" & vbNewLine & _
             vbTab & " default {" & vbNewLine
'            vbTab & "gpio-init-names = " & Chr(34) & "default" & Chr(34) & ";" & vbNewLine & _
'            vbTab & "gpio-init-0 = <&gpio_main_default>;" & vbNewLine & vbNewLine & _
'            vbTab & "gpio_main_default: default {" & vbNewLine
    
    ElseIf GPIOType = "UPHY" Then
        Output = "gpio@e8300000 {" & vbNewLine & _
            vbTab & " default {" & vbNewLine
'           vbTab & "gpio-init-names = " & Chr(34) & "default" & Chr(34) & ";" & vbNewLine & _
'           vbTab & "gpio-init-0 = <&gpio_main_default>;" & vbNewLine & vbNewLine & _
'           vbTab & "gpio_main_default: default {" & vbNewLine

    
    ElseIf GPIOType = "AON" Then
        Output = "gpio@8cf00000 {" & vbNewLine & _
            vbTab & " default {" & vbNewLine
'           vbTab & "gpio-init-names = " & Chr(34) & "default" & Chr(34) & ";" & vbNewLine & _
'           vbTab & "gpio-init-0 = <&gpio_aon_default>;" & vbNewLine & vbNewLine & _
'           vbTab & "gpio_aon_default: default {" & vbNewLine
         
    Else
        Output = "gpio@b0320000 {" & vbNewLine & _
            vbTab & " default {" & vbNewLine
'           vbTab & "gpio-init-names = " & Chr(34) & "default" & Chr(34) & ";" & vbNewLine & _
'           vbTab & "gpio-init-0 = <&gpio_fsi_default>;" & vbNewLine & vbNewLine & _
'           vbTab & "gpio_fsi_default: default {" & vbNewLine

    End If

    CurrentIndex = MaxSFIOIndex + 1
    If CurrentIndex <= MaxUsedIndex Then
        InputGPIOs = DoubleTab & "gpio-input = <" & vbNewLine & TripleTab
        OutputLowGPIOs = DoubleTab & "gpio-output-low = <" & vbNewLine & TripleTab
        OutputHighGPIOs = DoubleTab & "gpio-output-high = <" & vbNewLine & TripleTab
'        InputGPIOs = TripleTab & "gpio-input = <" & vbNewLine & QuadTab
'        OutputLowGPIOs = TripleTab & "gpio-output-low = <" & vbNewLine & QuadTab
'        OutputHighGPIOs = TripleTab & "gpio-output-high = <" & vbNewLine & QuadTab
    End If
'
    ' below logic order was modified on 3/28/2016. Move If GetEInput(MPIOConfigValue(CurrentIndex)) = "TEGRA_PIN_ENABLE" to
    ' the last position. When "GPIOInitValue" is equal to "o" or "1", the GPIO should be assigned to OutputLowGPIO or
    ' OutputHighGpio and not Input Gpio
    'Do While (CurrentIndex <= MaxUsedIndex) And (InStr(GPIOName(CurrentIndex), "MAIN") > 0)
    Do While (CurrentIndex <= MaxUsedIndex)
        If (InStr(GPIOName(CurrentIndex), GPIOType) > 0) Then
            If (GPIOInitValue(CurrentIndex) = 1) Then
                OutputHighGPIOs = OutputHighGPIOs & GPIOName(CurrentIndex) & vbNewLine & TripleTab
'                OutputHighGPIOs = OutputHighGPIOs & GPIOName(CurrentIndex) & vbNewLine & QuadTab
            ElseIf (GPIOInitValue(CurrentIndex) = 0) Then
                OutputLowGPIOs = OutputLowGPIOs & GPIOName(CurrentIndex) & vbNewLine & TripleTab
'                OutputLowGPIOs = OutputLowGPIOs & GPIOName(CurrentIndex) & vbNewLine & QuadTab
            ElseIf GetEInput(MPIOConfigValue(CurrentIndex)) = "TEGRA_PIN_ENABLE" Then
                InputGPIOs = InputGPIOs & GPIOName(CurrentIndex) & vbNewLine & TripleTab
'                InputGPIOs = InputGPIOs & GPIOName(CurrentIndex) & vbNewLine & QuadTab
                    'Else
                'MsgBox "Wrong GPIO Init Value Introduced for " & GPIOName(CurrentIndex)
                'RetVal = ERR_WRONG_GPIO_INIT
            End If
        End If
        CurrentIndex = CurrentIndex + 1
        If CurrentIndex > MaxUsedIndex Then
            InputGPIOs = InputGPIOs & ">;" & vbNewLine
            OutputLowGPIOs = OutputLowGPIOs & ">;" & vbNewLine
            OutputHighGPIOs = OutputHighGPIOs & ">;" & vbNewLine
        End If
    Loop

    Output = Output & InputGPIOs & OutputLowGPIOs & OutputHighGPIOs
    Output = Output & vbTab & "};" & vbNewLine & "};"
'    Output = Output & DoubleTab & "};" & vbNewLine & vbTab & "};"
    
    PrintGPIODT = RetVal
End Function

Function PrintPadVoltageFile(ByRef PadVoltageFilePath As String, ByRef PadVoltageFilename As String)
    Dim PadVoltageFileNum As Integer
    Dim RetVal As Integer
    Dim CurrentRow As Integer
    Dim LastRow As Integer
    Dim CurrentVoltage As String
    Dim CurrentRailName As String
    Dim Boardname As String
    Dim Ver As String
    
    RetVal = SUCCESS
    
    Boardname = InputBox("Type the board name.", "Board Name", LCase(Replace(ActiveSheet.Name, " Configuration", "")))
    If Boardname = "" Then
        MsgBox "BoardName cannot be empty."
        RetVal = ERR_EMPTY_NAME
        GoTo PrintPadVoltageFile_End
    End If
    Boardname = LCase(Boardname)
    
    PadVoltageFileNum = FreeFile()
    Open PadVoltageFilePath For Output As #PadVoltageFileNum
    If Err <> 0 Then
        RetVal = ERR_FILEIO
        GoTo PrintPadVoltageFile_End
    End If
    
    Ver = Range("D4")
    
    Print #PadVoltageFileNum, "/*This dtsi file was generated by " & Boardname & ".xlsm" & " Revision: " & Ver & " */"
    
    Print #PadVoltageFileNum, CopyRightMessage1
    Print #PadVoltageFileNum, CopyRightMessage2 & vbNewLine
'Additional statement added 8/4/2021
'    Print #PadVoltageFileNum, DoubleTab & "#define IO_PAD_VOLTAGE_1_2V 1200000"
'    Print #PadVoltageFileNum, DoubleTab & "#define IO_PAD_VOLTAGE_1_8V 1800000"
'    Print #PadVoltageFileNum, DoubleTab & "#define IO_PAD_VOLTAGE_3_3V 3300000"
    Print #PadVoltageFileNum, "#define IO_PAD_VOLTAGE_1_2V 1200000"
    Print #PadVoltageFileNum, "#define IO_PAD_VOLTAGE_1_8V 1800000"
    Print #PadVoltageFileNum, "#define IO_PAD_VOLTAGE_3_3V 3300000"
' Add below line on 11/15/2021
' Comment out below lines 9/16/2024
'   Print #PadVoltageFileNum, "/dts-v1/;", 9-16-2024
    Print #PadVoltageFileNum, ""
'   Print #PadVoltageFileNum, "/ {" , 9-16-2024
    Print #PadVoltageFileNum, ""
'   comment out below lines
'    Print #PadVoltageFileNum, vbTab & "pmc@8c800000 {"
'    Print #PadVoltageFileNum, DoubleTab & "io-pad-defaults {"
    Print #PadVoltageFileNum, "pmc@8c800000 {"
    Print #PadVoltageFileNum, vbTab & "io-pad-defaults {"
    

    CurrentRow = Range(RANGE_FIRST_PADVOLTAGECONFIG).Row
    LastRow = Range(RANGE_LAST_PADVOLTAGECONFIG).Row
    
    Do While CurrentRow <= LastRow
        CurrentRailName = LCase(Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_FIRST_PADVOLTAGECONFIG).Column).Value)
        CurrentVoltage = Worksheets(ActiveSheet.Name).Cells(CurrentRow, Range(RANGE_PADVOLTAGECONFIG).Column).Value
        
'        Print #PadVoltageFileNum, TripleTab & CurrentRailName & " {"
        Print #PadVoltageFileNum, DoubleTab & CurrentRailName & " {"
        If CurrentVoltage = "1.8V" Then
'            Print #PadVoltageFileNum, QuadTab & "nvidia,io-pad-init-voltage = <IO_PAD_VOLTAGE_1_8V>;"
            Print #PadVoltageFileNum, TripleTab & "nvidia,io-pad-init-voltage = <IO_PAD_VOLTAGE_1_8V>;"
        ElseIf CurrentVoltage = "1.2V" Then
'            Print #PadVoltageFileNum, QuadTab & "nvidia,io-pad-init-voltage = <IO_PAD_VOLTAGE_1_2V>;"
            Print #PadVoltageFileNum, TripleTab & "nvidia,io-pad-init-voltage = <IO_PAD_VOLTAGE_1_2V>;"
' below statement added May 4, 2018; Bug # 2107519
        ElseIf CurrentVoltage = "1.8V/3.3V_default_1.8V" Then
'            Print #PadVoltageFileNum, QuadTab & "nvidia,io-pad-init-voltage = <IO_PAD_VOLTAGE_1_8V>;"
            Print #PadVoltageFileNum, TripleTab & "nvidia,io-pad-init-voltage = <IO_PAD_VOLTAGE_1_8V>;"
'
        Else
'            Print #PadVoltageFileNum, QuadTab & "nvidia,io-pad-init-voltage = <IO_PAD_VOLTAGE_3_3V>;"
            Print #PadVoltageFileNum, TripleTab & "nvidia,io-pad-init-voltage = <IO_PAD_VOLTAGE_3_3V>;"
        End If
'        Print #PadVoltageFileNum, TripleTab & "};" & vbNewLine
        Print #PadVoltageFileNum, DoubleTab & "};" & vbNewLine
        CurrentRow = CurrentRow + 1
    Loop
'   Print #PadVoltageFileNum, DoubleTab & "};" & vbNewLine & vbTab & "};" & vbNewLine & "};"
    Print #PadVoltageFileNum, vbTab & "};" & vbNewLine & "};"

PrintPadVoltageFile_End:
    Close #PadVoltageFileNum
    PrintPadVoltageFile = RetVal
End Function
'
Function GenerateFile(ByRef PinmuxFilename As String, ByRef GPIOFilename As String, ByRef PadVoltageFilename As String)
    Dim Boardname As String
    Dim PinmuxFilePath As String
    Dim GPIOFilePath As String
    Dim PadVoltageFilePath As String
    Dim PinmuxFileNum As Integer
    Dim GPIOFileNum As Integer
    Dim MPIOIndex() As Integer
    Dim MPIOName() As String
    Dim SFIOName() As String
    Dim GPIOName() As String
    Dim GPIOInitValue() As Integer
    Dim MPIOConfigValue() As Integer
    Dim NumberOfMPIO As Integer
    Dim NumberOfSFIO As Integer
    Dim NumberOfGPIO As Integer
    Dim NumberOfUnused As Integer
    Dim StringToPrint As String
    Dim RetVal As Integer
    Dim Ver As String
    
    Boardname = InputBox("Type the board name.", "Board Name", LCase(Replace(ActiveSheet.Name, " Configuration", "")))
    If Boardname = "" Then
        MsgBox "BoardName cannot be empty."
        RetVal = ERR_EMPTY_NAME
        GoTo GenerateFile_End
    End If
    Boardname = LCase(Boardname)
    PinmuxFilename = "Thor-" & Boardname & "-pinmux.dtsi"
    GPIOFilename = "Thor-" & Boardname & "-gpio-default.dtsi"
    PadVoltageFilename = "Thor-" & Boardname & "-padvoltage-default.dtsi"
    PinmuxFilePath = ActiveWorkbook.Path & "\" & PinmuxFilename
    GPIOFilePath = ActiveWorkbook.Path & "\" & GPIOFilename
    PadVoltageFilePath = ActiveWorkbook.Path & "\" & PadVoltageFilename
    PinmuxFileNum = FreeFile()
    Open PinmuxFilePath For Output As #PinmuxFileNum
    If Err <> 0 Then
        RetVal = ERR_FILEIO
        GoTo GenerateFile_End
    End If
    GPIOFileNum = FreeFile()
    Open GPIOFilePath For Output As #GPIOFileNum
    If Err <> 0 Then
        RetVal = ERR_FILEIO
        GoTo GenerateFile_End
    End If
    
    RetVal = CountMPIO(NumberOfMPIO, NumberOfSFIO, NumberOfGPIO, NumberOfUnused)
    RetVal = GroupPins(MPIOIndex, MPIOName, SFIOName, GPIOName, GPIOInitValue, MPIOConfigValue, NumberOfSFIO, NumberOfGPIO, NumberOfUnused)
    If RetVal < 0 Then GoTo GenerateFile_End
    
    Ver = Range("D4")
    
    Print #PinmuxFileNum, "/*This dtsi file was generated by " & Boardname & ".xlsm" & " Revision: " & Ver & " */"
    
    Print #PinmuxFileNum, CopyRightMessage1
    Print #PinmuxFileNum, CopyRightMessage2 & vbNewLine
'   Print #PinmuxFileNum, PinmuxIncludeMessage & vbNewLine
'   Print #PinmuxFileNum, "/ {"
' Added below line 8/5/2021. Edited below line 11/15/2021
'   Print #PinmuxFileNum, "/dts-v1/;" & vbNewLine & "/ {"
'    Print #PinmuxFileNum, "/dts-v1/;"
    Print #PinmuxFileNum, ""
    Print #PinmuxFileNum, PinmuxIncludeMessage & vbNewLine
' Line below changed on 2/4/2022. PadVoltageFilename changed to GPIOFilename
    Print #PinmuxFileNum, PadVoltageIncludeMessage & GPIOFilename & Chr(34)
' Added below line 11/15/2021. Comment out below line 09/18/2024
'    Print #PinmuxFileNum, "/ {"
    Print #PinmuxFileNum, ""
'
'   Print #PinmuxFileNum, vbTab & "pinmux@2430000 {"
'    Print #PinmuxFileNum, vbTab & "pinmux@ac281000 {"
    Print #PinmuxFileNum, "pinmux@ac281000 {"
'   comment out below lines 09/18/2024
'    Print #PinmuxFileNum, DoubleTab & "pinctrl-names = " & Chr(34) & "default" & Chr(34) & ", " & _
'                    Chr(34) & "drive" & Chr(34) & ", " & Chr(34) & "unused" & Chr(34) & ";"
'    Print #PinmuxFileNum, DoubleTab & "pinctrl-0 = <&pinmux_default>;"
'    Print #PinmuxFileNum, DoubleTab & "pinctrl-1 = <&drive_default>;"
'    Print #PinmuxFileNum, DoubleTab & "pinctrl-2 = <&pinmux_unused_lowpower>;" & vbNewLine
'    Print #PinmuxFileNum, vbTab & "pinctrl-names = " & Chr(34) & "default" & Chr(34) & ", " & _
'                    Chr(34) & "drive" & Chr(34) & ", " & Chr(34) & "unused" & Chr(34) & ";"
'    Print #PinmuxFileNum, vbTab & "pinctrl-0 = <&pinmux_default>;"
'    Print #PinmuxFileNum, vbTab & "pinctrl-1 = <&drive_default>;"
'    Print #PinmuxFileNum, vbTab & "pinctrl-2 = <&pinmux_unused_lowpower>;" & vbNewLine
    
    RetVal = PrintPinmuxDT(StringToPrint, MPIOName, SFIOName, MPIOConfigValue, NumberOfSFIO, NumberOfGPIO, NumberOfUnused)
    Print #PinmuxFileNum, StringToPrint
'   below line commented out 09/18/2024
'    Print #PinmuxFileNum, vbTab & "};" & vbNewLine & "};"
    Print #PinmuxFileNum, "};" & vbNewLine & ""

    Print #GPIOFileNum, "/*This dtsi file was generated by " & Boardname & ".xlsm" & " Revision: " & Ver & " */"

    Print #GPIOFileNum, CopyRightMessage1
    Print #GPIOFileNum, CopyRightMessage2 & vbNewLine
    Print #GPIOFileNum, GPIOIncludeMessage & vbNewLine
'   Print #GPIOFileNum, "/dts-v1/;" & vbNewLine & "/ {"
'    Print #GPIOFileNum, vbNewLine & "/ {"
'    Print #GPIOFileNum, vbNewLine & "/ "
    RetVal = PrintGPIODT(StringToPrint, "MAIN", GPIOName, GPIOInitValue, MPIOConfigValue, NumberOfSFIO, NumberOfGPIO, NumberOfUnused)
    Print #GPIOFileNum, StringToPrint
    
    RetVal = PrintGPIODT(StringToPrint, "UPHY", GPIOName, GPIOInitValue, MPIOConfigValue, NumberOfSFIO, NumberOfGPIO, NumberOfUnused)
    Print #GPIOFileNum, StringToPrint
    
    RetVal = PrintGPIODT(StringToPrint, "AON", GPIOName, GPIOInitValue, MPIOConfigValue, NumberOfSFIO, NumberOfGPIO, NumberOfUnused)
    Print #GPIOFileNum, StringToPrint
    
    
    RetVal = PrintGPIODT(StringToPrint, "FSI", GPIOName, GPIOInitValue, MPIOConfigValue, NumberOfSFIO, NumberOfGPIO, NumberOfUnused)
    Print #GPIOFileNum, StringToPrint
'    Print #GPIOFileNum, vbNewLine & "};"
'    Print #GPIOFileNum, vbNewLine & " "
    
    RetVal = PrintPadVoltageFile(PadVoltageFilePath, PadVoltageFilename)
    
GenerateFile_End:
    Erase MPIOIndex()
    Erase MPIOName()
    Erase MPIOConfigValue()
    Close #PinmuxFileNum
    Close #GPIOFileNum
    
    GenerateFile = RetVal
End Function

Sub Generate_Device_Tree()
    Dim RetVal As Integer
    Dim PinmuxFilename As String
    Dim GPIOFilename As String
    Dim PadVoltageFilename As String

    ' Confirm if the user wants to generate device tree file.
    RetVal = MsgBox("Would you like to generate device tree file for pinmux table?", vbQuestion + vbYesNo)
    If RetVal = vbNo Then GoTo Generate_Device_Tree_End

    ' Check if valid choices are made. Quit otherwise.
    RetVal = SanityCheck()
    If RetVal <> SUCCESS Then GoTo Generate_Device_Tree_Error

    ' Start Generating Device Tree File
    RetVal = GenerateFile(PinmuxFilename, GPIOFilename, PadVoltageFilename)
    If RetVal <> SUCCESS Then GoTo Generate_Device_Tree_Error
    
    GoTo Generate_Device_Tree_Success

Generate_Device_Tree_Error:
    If RetVal = ERR_SANITY Then
        MsgBox "You made an invalid choice. Please check your configuration.", vbExclamation
    End If
    GoTo Generate_Device_Tree_End

Generate_Device_Tree_Success:
    MsgBox "Successfully wrote " & PinmuxFilename & " and " & GPIOFilename & " and " & PadVoltageFilename

Generate_Device_Tree_End:

End Sub


