Attribute VB_Name = "Create_Release_Customer_Pinmux"
'Delete the private variables
Sub Delete_Private_Variables()
    ActiveWorkbook.Names("E3301_Config_Table").Delete
    
End Sub
Sub Delete_Non_Releasable_Tabs_Except(ExceptConfigName As String, ExceptReadmeName As String)
'Delete all Worksheets that will not be included in the final file.
'ExceptConfigName: Name of Worksheet that will not be deleted
'ExceptReadmeName: Name of Readme Worksheet that will not be deleted

    Dim ws As Worksheet
    
    Application.CutCopyMode = False
    Application.DisplayAlerts = False
    
    For Each ws In Worksheets
        If (StrComp(ws.Name, ExceptConfigName, vbTextCompare) <> 0) And (StrComp(ws.Name, ExceptReadmeName, vbTextCompare) <> 0) Then
            ws.Delete
        End If
    Next ws
    
    Application.DisplayAlerts = True
End Sub
Sub Create_Release_Customer_Pinmux()
'
' Create_Release_Customer_Pinmux Macro
'

'
' Save to a New File
    ActiveWorkbook.SaveAs FileName:="T194_Internal_pinmux_Config.xlsm", _
        FileFormat:=xlOpenXMLWorkbookMacroEnabled, CreateBackup:=False
' Remove Links from Customer Configuration Tab
    Sheets("T194-Internal-Config").Select
    Columns("A:AN").Select
    Range("AN1").Activate
    Selection.Copy
    Selection.PasteSpecial Paste:=xlPasteValues, Operation:=xlNone, SkipBlanks _
        :=False, Transpose:=False

' Delete Non-releasable Tabs
    Delete_Non_Releasable_Tabs_Except "T194-Internal-Config", "Customer-Readme"
    
' Delete Private Variables
    Delete_Private_Variables

' Protect Existing Tabs
    Sheets("T194-Internal-Config").Select
    ActiveSheet.Protect DrawingObjects:=True, Contents:=True, Scenarios:=True
    Sheets("Customer-Readme").Select
    ActiveSheet.Protect DrawingObjects:=True, Contents:=True, Scenarios:=True
' Save File
    ActiveWorkbook.Save

End Sub

Sub Create_ExtRelease_Customer_Pinmux()
'
' Create_External -Release_Customer_Pinmux Macro
'

'
' Save to a New File
    ActiveWorkbook.SaveAs FileName:="T194_Ext_customer_Config_release.xlsm", _
        FileFormat:=xlOpenXMLWorkbookMacroEnabled, CreateBackup:=False
' Remove Links from Customer Configuration Tab
    Sheets("T194-Ext-Customer-Config").Select
    Columns("A:AN").Select
    Range("AN1").Activate
    Selection.Copy
    Selection.PasteSpecial Paste:=xlPasteValues, Operation:=xlNone, SkipBlanks _
        :=False, Transpose:=False

' Delete Non-releasable Tabs
    Delete_Non_Releasable_Tabs_Except "T194-Ext-Customer-Config", "Customer-Readme"
    
' Delete Private Variables
    Delete_Private_Variables

' Protect Existing Tabs
    Sheets("T194-Ext-Customer-Config").Select
    ActiveSheet.Protect DrawingObjects:=True, Contents:=True, Scenarios:=True
    Sheets("Customer-Readme").Select
    ActiveSheet.Protect DrawingObjects:=True, Contents:=True, Scenarios:=True
' Save File
    ActiveWorkbook.Save

End Sub
Sub Create_Release_Automotive_Customer_VCM_Pinmux()
'
' Create_Release_Customer_Pinmux Macro
'

'
' Save to a New File
    ActiveWorkbook.SaveAs FileName:="VCM3.1TegraParkerPinmux.xlsm", _
        FileFormat:=xlOpenXMLWorkbookMacroEnabled, CreateBackup:=False
' Remove Links from Customer Configuration Tab
    Sheets("VCM3.1-Cust-Config").Select
    Columns("A:AC").Select
    Range("Z1").Activate
    Selection.Copy
    Selection.PasteSpecial Paste:=xlPasteValues, Operation:=xlNone, SkipBlanks _
        :=False, Transpose:=False
        
' Delete Non-releasable Tabs
    Delete_Non_Releasable_Tabs_Except "VCM3.1-Cust-Config", "Customer-Readme"
    
' Delete Private Variables
    Delete_Private_Variables
    
' Protect Existing Tabs
    Sheets("VCM3.1-Cust-Config").Select
    ActiveSheet.Protect DrawingObjects:=True, Contents:=True, Scenarios:=True
    Sheets("Customer-Readme").Select
    ActiveSheet.Protect DrawingObjects:=True, Contents:=True, Scenarios:=True

' Save File
    ActiveWorkbook.Save

End Sub

Sub Create_Release_T194_Auto_Pinmux_Template()
'
' Create_Release_Customer_Pinmux Macro
'

'
' Save to a New File
    ActiveWorkbook.SaveAs FileName:="T194-Auto-Pinmux-Config-Template.xlsm", _
        FileFormat:=xlOpenXMLWorkbookMacroEnabled, CreateBackup:=False
' Remove Links from Customer Configuration Tab
    Sheets("T194-Auto-Config-Template").Select
    Columns("A:AA").Select
    Range("Z1").Activate
    Selection.Copy
    Selection.PasteSpecial Paste:=xlPasteValues, Operation:=xlNone, SkipBlanks _
        :=False, Transpose:=False
        
' Delete Non-releasable Tabs
    Delete_Non_Releasable_Tabs_Except "T194-Auto-Config-Template", "Customer-Readme"
    
' Delete Private Variables
'    Delete_Private_Variables
    
' Protect Existing Tabs
    Sheets("T194-Auto-Config-Template").Select
    ActiveSheet.Protect DrawingObjects:=True, Contents:=True, Scenarios:=True
    Sheets("Customer-Readme").Select
    ActiveSheet.Protect DrawingObjects:=True, Contents:=True, Scenarios:=True

' Save File
    ActiveWorkbook.Save

End Sub
Sub Create_Release_Automotive_Customer_DDPX_Pinmux_Template()
'
' Create_Release_Customer_Pinmux Macro
'

'
' Save to a New File
    ActiveWorkbook.SaveAs FileName:="T194-Auto-Pinmux-Config-E3550-B00-X1.xlsm", _
        FileFormat:=xlOpenXMLWorkbookMacroEnabled, CreateBackup:=False
' Remove Links from Customer Configuration Tab
    Sheets("E3550-B00-X1").Select
    Columns("A:AA").Select
    Range("Z1").Activate
    Selection.Copy
    Selection.PasteSpecial Paste:=xlPasteValues, Operation:=xlNone, SkipBlanks _
        :=False, Transpose:=False
        
' Delete Non-releasable Tabs
    Delete_Non_Releasable_Tabs_Except "E3550-B00-X1", "Customer-Readme"
    
' Delete Private Variables
'   Delete_Private_Variables
    
' Protect Existing Tabs
'    Sheets("E3550-B00-X1").Select
'    ActiveSheet.Protect DrawingObjects:=True, Contents:=True, Scenarios:=True
'    Sheets("Customer-Readme").Select
'    ActiveSheet.Protect DrawingObjects:=True, Contents:=True, Scenarios:=True

' Save File
    ActiveWorkbook.Save

End Sub

Sub Create_Release_Automotive_Customer_DDPX_X2_Pinmux_Template()
'
' Create_Release_Customer_Pinmux Macro
'

'
' Save to a New File
    ActiveWorkbook.SaveAs FileName:="T194-Auto-Pinmux-Config-E3550-B00-X2.xlsm", _
        FileFormat:=xlOpenXMLWorkbookMacroEnabled, CreateBackup:=False
' Remove Links from Customer Configuration Tab
    Sheets("E3550-B00-X2").Select
    Columns("A:AA").Select
    Range("Z1").Activate
    Selection.Copy
    Selection.PasteSpecial Paste:=xlPasteValues, Operation:=xlNone, SkipBlanks _
        :=False, Transpose:=False
        
' Delete Non-releasable Tabs
    Delete_Non_Releasable_Tabs_Except "E3550-B00-X2", "Customer-Readme"
    
' Delete Private Variables
'   Delete_Private_Variables
    
' Protect Existing Tabs
'    Sheets("E3550-B00-X1").Select
'    ActiveSheet.Protect DrawingObjects:=True, Contents:=True, Scenarios:=True
'    Sheets("Customer-Readme").Select
'    ActiveSheet.Protect DrawingObjects:=True, Contents:=True, Scenarios:=True

' Save File
    ActiveWorkbook.Save

End Sub

Sub Create_Release_Galen_For_Key_Customers_Customer_Pinmux()
'
' Create_Release_Customer_Pinmux Macro
'

'
' Save to a New File
    ActiveWorkbook.SaveAs FileName:="Xavier_CVM_Direct_Support_Customer_Blank_Pinmux.xlsm", _
        FileFormat:=xlOpenXMLWorkbookMacroEnabled, CreateBackup:=False
' Remove Links from Customer Configuration Tab
    Sheets("P2888_Galen_DevKit").Select
    Columns("A:AC").Select
    Range("Z1").Activate
    Selection.Copy
    Selection.PasteSpecial Paste:=xlPasteValues, Operation:=xlNone, SkipBlanks _
        :=False, Transpose:=False
        
' Delete Non-releasable Tabs
    Delete_Non_Releasable_Tabs_Except "P2888_Galen_DevKit", "Customer-Readme"
    
' Delete Private Variables
'    Delete_Private_Variables
    
' Protect Existing Tabs
'   Sheets("P2888_Galen_DevKit").Select
'   ActiveSheet.Protect DrawingObjects:=True, Contents:=True, Scenarios:=True
'   Sheets("Customer-Readme").Select
'   ActiveSheet.Protect DrawingObjects:=True, Contents:=True, Scenarios:=True

' Save File
    ActiveWorkbook.Save

End Sub

Sub Create_Release_Jetson_For_Generic_Customer_Pinmux()
'
' Create_Release_Customer_Pinmux Macro
'

'
' Save to a New File
    ActiveWorkbook.SaveAs FileName:="Jetson_TX1_Generic_Customer_Pinmux.xlsm", _
        FileFormat:=xlOpenXMLWorkbookMacroEnabled, CreateBackup:=False
' Remove Links from Customer Configuration Tab
    Sheets("Jetson TX1 Cust. Config.").Select
    Columns("A:Z").Select
    Range("Z1").Activate
    Selection.Copy
    Selection.PasteSpecial Paste:=xlPasteValues, Operation:=xlNone, SkipBlanks _
        :=False, Transpose:=False
    Columns("AN:AW").Select
    Range("AW1").Activate
    Selection.Copy
    Selection.PasteSpecial Paste:=xlPasteValues, Operation:=xlNone, SkipBlanks _
        :=False, Transpose:=False
        
' Delete Non-releasable Tabs
    Delete_Non_Releasable_Tabs_Except "Jetson TX1 Cust. Config.", "Customer-Readme"
    
' Delete Private Variables
    Delete_Private_Variables
    
' Protect Existing Tabs
    Sheets("Jetson TX1 Cust. Config.").Select
    ActiveSheet.Protect DrawingObjects:=True, Contents:=True, Scenarios:=True
    Sheets("Customer-Readme").Select
    ActiveSheet.Protect DrawingObjects:=True, Contents:=True, Scenarios:=True

' Save File
    ActiveWorkbook.Save

End Sub


