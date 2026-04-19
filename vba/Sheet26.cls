VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Sheet26"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = True
'Function to check that the pin direction selected matches the customer usage
Function IsPinDirectionValid(ByVal CurrentRow As Long) As Boolean
    SelectedCustomerUsage = Cells(CurrentRow, Range(RANGE_CUSTOMER_USAGE).Column).Value
    SelectedPinDirection = Cells(CurrentRow, Range(RANGE_PIN_DIRECTION).Column).Value
    
    ' Error Check: A pin direction should not be set for an unused pin.
    If Left(SelectedCustomerUsage, 7) = "unused_" And SelectedPinDirection <> "Not Assigned" And SelectedPinDirection <> "" Then
        IsPinDirectionValid = False
        MsgBox "Error: Cannot assign a pin direction for an unused pin."
        Exit Function
    ElseIf SelectedPinDirection = "Not Assigned" Then
        IsPinDirectionValid = True
        Exit Function
    End If
     
    'Find the Allowed Pin Direction based on the selected Customer Usage
    If SelectedCustomerUsage = Cells(CurrentRow, Range(RANGE_PINMUX_GPIO).Column).Value Then
        AllowedPinDirection = Cells(CurrentRow, Range(RANGE_ALLOWED_PIN_DIRECTION_GPIO).Column).Value
    ElseIf SelectedCustomerUsage = Cells(CurrentRow, Range(RANGE_PINMUX_SFIO0).Column).Value Then
        AllowedPinDirection = Cells(CurrentRow, Range(RANGE_ALLOWED_PIN_DIRECTION_SFIO0).Column).Value
    ElseIf SelectedCustomerUsage = Cells(CurrentRow, Range(RANGE_PINMUX_SFIO1).Column).Value Then
        AllowedPinDirection = Cells(CurrentRow, Range(RANGE_ALLOWED_PIN_DIRECTION_SFIO1).Column).Value
    ElseIf SelectedCustomerUsage = Cells(CurrentRow, Range(RANGE_PINMUX_SFIO2).Column).Value Then
        AllowedPinDirection = Cells(CurrentRow, Range(RANGE_ALLOWED_PIN_DIRECTION_SFIO2).Column).Value
    ElseIf SelectedCustomerUsage = Cells(CurrentRow, Range(RANGE_PINMUX_SFIO3).Column) Then
        AllowedPinDirection = Cells(CurrentRow, Range(RANGE_ALLOWED_PIN_DIRECTION_SFIO3).Column)
    End If
        
    If AllowedPinDirection = "I" And SelectedPinDirection <> "Input" Then
        IsPinDirectionValid = False
        MsgBox ("Error: " & SelectedCustomerUsage & " should not be set as " & SelectedPinDirection & ".")
    ElseIf AllowedPinDirection = "O" And SelectedPinDirection <> "Output" Then
        IsPinDirectionValid = False
        MsgBox ("Error: " & SelectedCustomerUsage & " should not be set as " & SelectedPinDirection & ".")
    Else
        IsPinDirectionValid = True
    End If
End Function

'Function to check that the customer usage is not blank
Function IsCustomerUsageNotBlank(ByVal CurrentRow As Long) As Boolean
    If Cells(CurrentRow, Range(RANGE_CUSTOMER_USAGE).Column).Value = "" Then
        MsgBox ("Error: Customer Usage cannot be blank")
        IsCustomerUsageNotBlank = False
    Else
        IsCustomerUsageNotBlank = True
    End If
End Function

'Function to check that the resistor configurations are compatible
Function IsResistorConfigurationGood(ByVal CurrentRow As Long) As Boolean
    SelectedInitialState = Cells(CurrentRow, Range(RANGE_INITIAL_STATE).Column).Value
    SelectedExtPU = Cells(CurrentRow, Range(RANGE_EXT_PU).Column).Value
    SelectedExtPD = Cells(CurrentRow, Range(RANGE_EXT_PD).Column).Value
    
    If SelectedInitialState = "Int PU" And SelectedExtPU <> "" Then
        MsgBox ("Error: Internal pull up cannot be enabled if there is an external pull up.")
        IsResistorConfigurationGood = False
    ElseIf SelectedInitialState = "Int PU" And SelectedExtPD <> "" Then
        MsgBox ("Error: Internal pull up cannot be enabled if there is an external pull down.")
        IsResistorConfigurationGood = False
    ElseIf SelectedInitialState = "Int PD" And SelectedExtPU <> "" Then
        MsgBox ("Error: Internal pull down cannot be enabled if there is an external pull up.")
        IsResistorConfigurationGood = False
    ElseIf SelectedInitialState = "Int PD" And SelectedExtPD <> "" Then
        MsgBox ("Error: Internal pull down cannot be enabled if there is an external pull down.")
        IsResistorConfigurationGood = False
    Else
        IsResistorConfigurationGood = True
    End If
End Function

'Function to check that the Initial State is valid
Function IsInitialStateValid(ByVal CurrentRow As Long) As Boolean
    SelectedCustomerUsage = Cells(CurrentRow, Range(RANGE_CUSTOMER_USAGE).Column).Value
    SelectedInitialState = Cells(CurrentRow, Range(RANGE_INITIAL_STATE).Column).Value

    ' Error Check: An Initial State should not be set for an unused pin.
    If Left(SelectedCustomerUsage, 7) = "unused_" And SelectedInitialState <> "" And SelectedInitialState <> "Z" And SelectedInitialState <> "N/A" Then
        MsgBox "Error: Initial State for an Unused Pin cannot be assigned to " & SelectedInitialState & "."
        IsInitialStateValid = False
    Else
        IsInitialStateValid = True
    End If
End Function

'Function to check that the Wake is valid
Function IsWakeValid(ByVal CurrentRow As Long) As Boolean
    IsWakeValid = True
    SelectedWakePin = Cells(CurrentRow, Range(RANGE_WAKE_PIN).Column).Value
    SelectedPinDirection = Cells(CurrentRow, Range(RANGE_PIN_DIRECTION).Column).Value
    SelectedCustomerUsage = Cells(CurrentRow, Range(RANGE_CUSTOMER_USAGE).Column).Value
    
    'Skip if Wake is blank.
    If SelectedWakePin = "" Then
        Exit Function
    End If
    
    'Error Check: Wake Pin cannot be assigned to an Unused pin
    If SelectedWakePin = "Yes" And Left(SelectedCustomerUsage, 7) = "unused_" Then
        MsgBox ("Error: Wake cannot be enabled on an Unused Pin")
        IsWakeValid = False
    End If
    
    'Error Check: Wake Pin cannot be assigned to an output or unassigned pin
    If SelectedWakePin = "Yes" And SelectedPinDirection = "Output" Then
        MsgBox ("Error: Wake cannot be enabled on an Output")
        IsWakeValid = False
    ElseIf SelectedWakePin = "Yes" And SelectedPinDirection = "Not Assigned" Then
        MsgBox ("Error: Wake cannot be enabled on an Unassigned pin")
        IsWakeValid = False
    End If
    
End Function

'Function to check that the 3.3V Tolerance Enable (RCV_SEL) is valid
Function IsRCVSELValid(ByVal CurrentRow As Long) As Boolean
    IsRCVSELValid = True
    SelectedRCVSEL = Cells(CurrentRow, Range(RANGE_RCV_SEL).Column).Value
    SelectedCustomerUsage = Cells(CurrentRow, Range(RANGE_CUSTOMER_USAGE).Column).Value
    
    'Do not check if the RCV_SEL is Blank.
    If SelectedRCVSEL = "" Then
        Exit Function
    End If
    
    'Error Check: RCV_SEL Pin cannot be assigned to an Unused pin
    If SelectedRCVSEL = "Enable" And Left(SelectedCustomerUsage, 7) = "unused_" Then
        MsgBox ("Error: 3.3V Tolerance cannot be enabled on an Unused Pin")
        IsRCVSELValid = False
    End If

End Function

Private Sub Worksheet_Change(ByVal Target As Range)
    ' The variable KeyCells contains the cells that will
    ' cause an alert when they are changed.
    Dim KeyCells As Range
    
    ' The variable contains the location of the last MPIO
    FirstMpioRow = Range(RANGE_FIRST_MPIO).Row
    
    ' The variable contains the location of the last MPIO
    LastMPIORow = Range(RANGE_LAST_MPIO).Row - 1
    
    ' The variable contains the current row
    CurrentRow = Target.Row
    
    'Check for Changes in the Customer Usage Column
    Set KeyCells = Range(Cells(FirstMpioRow, Range(RANGE_CUSTOMER_USAGE).Column), Cells(LastMPIORow, Range(RANGE_CUSTOMER_USAGE).Column))
    If Not Application.Intersect(KeyCells, Range(Target.Address)) _
           Is Nothing Then
        ' Error Check: Check that the Customer Usage is not blank
        Result = IsCustomerUsageNotBlank(CurrentRow)
        Cells(CurrentRow, Range(RANGE_CUSTOMER_USAGE_CHECKER).Column).Value = Result
        If Not (Result) Then
            Exit Sub
        End If
        
        
        ' Error Check: Check that the Pin Direction is set correctly
        Cells(CurrentRow, Range(RANGE_PIN_DIRECTION_CHECKER).Column).Value = IsPinDirectionValid(CurrentRow)
        
        ' Error Check: RCV_SEL can only been enabled on a used pin
        Cells(CurrentRow, Range(RANGE_RCV_SEL_CHECKER).Column).Value = IsRCVSELValid(CurrentRow)
        
        ' Error Check: Wake can only been enabled on an Input, Bidirectional, or Open Drain
        Cells(CurrentRow, Range(RANGE_WAKE_CHECKER).Column).Value = IsWakeValid(CurrentRow)
        
        ' Warning Check: Check if a usage of a function is allowed by Nvidia
        If Right(Target.Value, 1) = "*" Then
            MsgBox "Warning: Please check with Nvidia AEs before using this function."
        End If
    End If
    
    'Check for Changes in the Pin Direction Column
    Set KeyCells = Range(Cells(FirstMpioRow, Range(RANGE_PIN_DIRECTION).Column), Cells(LastMPIORow, Range(RANGE_PIN_DIRECTION).Column))
    If Not Application.Intersect(KeyCells, Range(Target.Address)) _
           Is Nothing Then
        ' Error Check: Check that the Pin Direction is set correctly
        Cells(CurrentRow, Range(RANGE_PIN_DIRECTION_CHECKER).Column).Value = IsPinDirectionValid(CurrentRow)
        ' Error Check: Wake can only been enabled on an Input, Bidirectional, or Open Drain
        Cells(CurrentRow, Range(RANGE_WAKE_CHECKER).Column).Value = IsWakeValid(CurrentRow)
    End If
    
    'Check for Changes in the Initial State Column
    Set KeyCells = Range(Cells(FirstMpioRow, Range(RANGE_INITIAL_STATE).Column), Cells(LastMPIORow, Range(RANGE_INITIAL_STATE).Column))
    If Not Application.Intersect(KeyCells, Range(Target.Address)) _
           Is Nothing Then
        ' Error Check: Initial state conflict
        Cells(CurrentRow, Range(RANGE_INITIAL_STATE_CHECKER).Column).Value = IsInitialStateValid(CurrentRow)
        ' Error Check: For external and internal pull up/down resistor conflict
        Cells(CurrentRow, Range(RANGE_RESISTOR_CHECKER).Column).Value = IsResistorConfigurationGood(CurrentRow)
    End If
    
    'Check for Changes in the Wake Pin Column
    Set KeyCells = Range(Cells(FirstMpioRow, Range(RANGE_WAKE_PIN).Column), Cells(LastMPIORow, Range(RANGE_WAKE_PIN).Column))
    If Not Application.Intersect(KeyCells, Range(Target.Address)) _
           Is Nothing Then
      ' Error Check: Wake can only been enabled on an Input, Bidirectional, or Open Drain
        Cells(CurrentRow, Range(RANGE_WAKE_CHECKER).Column).Value = IsWakeValid(CurrentRow)
    End If
    
    'Check for Changes in the Ext Pull Up Column
    Set KeyCells = Range(Cells(FirstMpioRow, Range(RANGE_EXT_PU).Column), Cells(LastMPIORow, Range(RANGE_EXT_PU).Column))
    If Not Application.Intersect(KeyCells, Range(Target.Address)) _
           Is Nothing Then
        ' Error Check: For external and internal pull up/down resistor conflict
        Cells(CurrentRow, Range(RANGE_RESISTOR_CHECKER).Column).Value = IsResistorConfigurationGood(CurrentRow)
    End If
    
    'Check for Changes in the Ext Pull Down Column
    Set KeyCells = Range(Cells(FirstMpioRow, Range(RANGE_EXT_PD).Column), Cells(LastMPIORow, Range(RANGE_EXT_PD).Column))
    If Not Application.Intersect(KeyCells, Range(Target.Address)) _
           Is Nothing Then
        ' Error Check: For external and internal pull up/down resistor conflict
        Cells(CurrentRow, Range(RANGE_RESISTOR_CHECKER).Column).Value = IsResistorConfigurationGood(CurrentRow)
    End If
    
    'Check for Changes in the 3.3V Tolerance Enable Column
    Set KeyCells = Range(Cells(FirstMpioRow, Range(RANGE_RCV_SEL).Column), Cells(LastMPIORow, Range(RANGE_RCV_SEL).Column))
    If Not Application.Intersect(KeyCells, Range(Target.Address)) _
           Is Nothing Then
      ' Error Check: RCV_SEL can only been enabled on a used pin
        Cells(CurrentRow, Range(RANGE_RCV_SEL_CHECKER).Column).Value = IsRCVSELValid(CurrentRow)
    End If
    
End Sub

