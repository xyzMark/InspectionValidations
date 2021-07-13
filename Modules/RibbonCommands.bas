Attribute VB_Name = "RibbonCommands"

'*************************************************************************************************
'
'   RibbonCommands
'       Event logic for the Custom Ribbon Controls
'       1. The JobID Field and our editText Form should be updated to be the same when chanes are applied
'       2. The RoutineSelection and our ComboBox should be updated to be the same when changes are applied
'       3. we should ask the DataBase Module to perform our check on whether a jobNumber actually exists and is valid
'*************************************************************************************************

'Epicor Job Info
Public jobNumUcase As String
Public customer As String
Public partNum As String
Public rev As String
Public machine As String
Public cell As String
Public partDesc As String
Public drawNum As String
Public prodQty As Integer

'Routines for the part / Routines that we've run
Public partRoutineList() As Variant
Public runRoutineList() As Variant

'Features and Measurement Information, applicable to the currently selected Routine
Dim featureHeaderInfo() As Variant
Dim featureMeasuredValues() As Variant
Dim featureTraceabilityInfo() As Variant

'Ribbon Controls
Dim cusRibbon As IRibbonUI

Private toggAutoForm_Pressed As Boolean
Public toggML7TestDB_Pressed As Boolean
Public toggShowAllObs_Pressed As Boolean

Dim lblStatus_Text As String

Dim rtCombo_TextField As String
Dim rtCombo_Enabled As Boolean

Public chkFull_Pressed As Boolean
Public chkMini_Pressed As Boolean
Public chkNone_Pressed As Boolean




''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'               UI Ribbon
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

Public Sub Ribbon_OnLoad(uiRibbon As IRibbonUI)
    Set cusRibbon = uiRibbon
    cusRibbon.ActivateTab "mlTab"
    
End Sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'               LoadForm Button
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

Public Sub Callback(ByRef control As Office.IRibbonControl)
    VettingForm.Show
End Sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'              Show All Observations Toggle Buttom
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

Public Sub allObs_Toggle(ByRef control As Office.IRibbonControl, ByRef isPressed As Boolean)
    toggShowAllObs_Pressed = isPressed
End Sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'               Auto Load Form Toggle Button
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Public Sub toggAutoForm_Toggle(ByRef control As Office.IRibbonControl, ByRef isPressed As Boolean)
    toggAutoForm_Pressed = isPressed
End Sub
Public Sub toggAutoForm_OnGetPressed(ByRef control As Office.IRibbonControl, ByRef ReturnedValue As Variant)
    ReturnedValue = True
    toggAutoForm_Pressed = True
End Sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'               ML7 Test Database Toggle Button
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Public Sub testDB_Toggle(ByRef control As Office.IRibbonControl, ByRef isPressed As Boolean)
    toggML7TestDB_Pressed = isPressed
    Call DatabaseModule.Close_Connections 'If we had a connection already open, need to invalidate it so we can connect to the TestDB
End Sub

Public Sub testDB_OnGetEnabled(ByRef control As Office.IRibbonControl, ByRef ReturnedValue As Variant)
    ReturnedValue = False
End Sub


''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'               Job Number EditTextField
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Public Sub jbEditText_onGetText(ByRef control As IRibbonControl, ByRef Text)
    Text = jobNumUcase
    
    'Ask the workbook to Add the Information to Header Fields
'    Call ThisWorkbook.populateJobHeaders(jobNum:=jobNumUcase, routine:=rtCombo_TextField, customer:=customer, machine:=machine, partNum:=partNum, rev:=rev, partDesc:=partDesc)
'    Call ThisWorkbook.populateReport(featureInfo:=featureHeaderInfo, featureMeasurements:=featureMeasuredValues, featureTraceability:=featureTraceabilityInfo)
    
End Sub

Public Sub jbEditText_OnChange(ByRef control As Office.IRibbonControl, ByRef Text As String)
    'Reset the Variables
    Call ClearVariables
    
    jobNumUcase = UCase(Text)
    If Text = vbNullString Then GoTo 10
    
    Dim setupType As String
    
    If DatabaseModule.GetJobInformation(JobID:=Text, partNum:=partNum, rev:=rev, setupType:=setupType, machine:=machine, cell:=cell, _
                                        partDescription:=partDesc, prodQty:=prodQty, drawNum:=drawNum) Then
    
        customer = DatabaseModule.GetCustomerName(jobNum:=jobNumUcase)
    
        On Error GoTo ML_NotApplicable:
        'TODO create two respective routine retrievals for both run and Part
        tempRoutineArray = DatabaseModule.GetRunRoutineList(jobNumUcase)
        partRoutineList = DatabaseModule.GetPartRoutineList(partNum, rev)
        
        ReDim Preserve runRoutineList(2, UBound(tempRoutineArray, 2))
        For i = 0 To UBound(tempRoutineArray, 2)
            runRoutineList(0, i) = tempRoutineArray(0, i)
            runRoutineList(1, i) = tempRoutineArray(1, i)
        Next i
        
        'TODO: reset the error handling here, test with a 1/0 math
        
        rtCombo_TextField = runRoutineList(0, 0)
        lblStatus_Text = runRoutineList(1, 0)
        rtCombo_Enabled = True

        Select Case setupType
            Case "Full"
                chkFull_Pressed = True
            Case "Mini"
                chkMini_Pressed = True
            Case "None"
                chkNone_Pressed = True
            Case Else
                'Todo: Handle we don't know what the setupType is.
        End Select
        
        Call SetVariabes

        For i = 0 To UBound(runRoutineList, 2)
            Dim routine As String
            routine = runRoutineList(0, i)
            Dim features() As Variant
            features = DatabaseModule.GetFeatureHeaderInfo(jobNum:=jobNumUcase, routine:=routine)
            
            'Find the total number of observations for each routine
            'TODO: This is NOT conditionally switching on All/Pass Observations
            
            If toggShowAllObs_Pressed Then
                runRoutineList(2, i) = UBound(DatabaseModule.GetAllFeatureMeasuredValues(jobNum:=jobNumUcase, routine:=routine, _
                                                delimFeatures:=JoinPivotFeatures(features)), 2) + 1
            Else
                runRoutineList(2, i) = UBound(DatabaseModule.GetFeatureMeasuredValues(jobNum:=jobNumUcase, routine:=routine, _
                                                delimFeatures:=JoinPivotFeatures(features), featureInfo:=features), 2) + 1
            End If
            
             
        Next i
        

    Else
        MsgBox ("Not A Valid Job Number")
        jobNumUcase = ""
    End If
10
    'TODO: set error handling here for us not holding refernce to the ribbon control anymore

    
    'Standard updates that are always applicable
    cusRibbon.InvalidateControl "chkFull"
    cusRibbon.InvalidateControl "chkMini"
    cusRibbon.InvalidateControl "chkNone"
    cusRibbon.InvalidateControl "rtCombo"
    cusRibbon.InvalidateControl "jbEditText"
    cusRibbon.InvalidateControl "lblStatus"
    
    Call SetWorkbookInformation
    
    If toggAutoForm_Pressed Then VettingForm.Show

    Exit Sub

ML_NotApplicable:
    MsgBox Prompt:="No Routines Found for this Job or Part Number " & vbCrLf & "If this is a MeasurLink Job, bring to QE's attention ", Buttons:=vbExclamation
    GoTo 10
    
End Sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'               RoutineName ComboBox
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Public Sub rtCombo_OnChange(ByRef control As Office.IRibbonControl, ByRef Text As Variant)
    'There doesn't seem to be a property to prevent the user from Hand-Typing into the ComboBox
    'So we have to make sure that the change is legitimate
    Dim validChange As Boolean
    validChange = False
    
    If Not Not runRoutineList Then
        For i = 0 To UBound(runRoutineList, 2)
            If Text = runRoutineList(0, i) Then
            
                'Erase old feature data
                validChange = True
                Exit For
'                Call ClearVariables(preserveRoutines:=True)
'
'                'Set new active routine
'                lblStatus_Text = runRoutineList(1, i)
'                rtCombo_TextField = Text
'
'                'Get new feature data with new active routine
'                Call SetVariabes
'                Call SetWorkbookInformation
'
            End If
        Next i
    End If
    
    Call ClearVariables(preserveRoutines:=True)
    
    If validChange = True Then
         'Set new active routine
        lblStatus_Text = runRoutineList(1, i)
        rtCombo_TextField = Text
        
        'Get new feature data with new active routine
        Call SetVariabes
    End If
    
    'If there was new data we populate, if not then we clear everything
    Call SetWorkbookInformation
    
    cusRibbon.InvalidateControl "rtCombo"
    cusRibbon.InvalidateControl "jbEditText"
    cusRibbon.InvalidateControl "lblStatus"
    
End Sub

Public Sub rtCombo_OnGetEnabled(ByRef control As IRibbonControl, ByRef Enabled As Variant)
    Enabled = rtCombo_Enabled
End Sub

Public Sub rtCombo_OnGetItemCount(ByRef control As Office.IRibbonControl, ByRef Count As Variant)
    If Not IsEmpty(runRoutineList) Then
        Count = UBound(runRoutineList, 2) + 1
    End If
End Sub

Public Sub rtCombo_OnGetItemLabel(ByRef control As Office.IRibbonControl, ByRef index As Integer, ByRef ItemLabel As Variant)
    ItemLabel = runRoutineList(0, index)
End Sub

Public Sub rtCombo_OnGetItemID(ByRef control As Office.IRibbonControl, ByRef index As Integer, ByRef ItemID As Variant)
    'TODO
    'Debug.Print ("hit the get item ID")
End Sub

Public Sub rtCombo_OnGetText(ByRef control As Office.IRibbonControl, ByRef Text As Variant)
    'Believe it or not, this is the proper way to check if a Variant Array has been initialized
    'TODO: do we even need to check if this array is initialized? Maybe we can just check rtCombo_TextField here
    If Not Not runRoutineList Then
        Text = rtCombo_TextField
    Else
        Text = "[SELECT ROUTINE]"
    End If
    
    'TODO: currently commenting this out, hoping that we can populate the headers exclusively with jbEditText_OnGetText()
        'Ask the workbook to Add the Information to Header Fields
'    ThisWorkbook.populateHeaders jobNum:=jobNumUcase, routine:=rtCombo_TextField

End Sub



''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'               RunStatus Label
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

Public Sub lblStatus_OnGetLabel(ByRef control As Office.IRibbonControl, ByRef Label As Variant)
    If lblStatus_Text = vbNullString Then
        Label = ""
    Else
        Label = lblStatus_Text
    End If
End Sub




''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'               JobType Check Boxes
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

Public Sub chkFull_OnAction(ByRef control As IRibbonControl, ByRef pressed As Boolean)
    'TODO:
End Sub

Public Sub chkFull_OnGetEnabled(ByRef control As IRibbonControl, ByRef Enabled As Variant)
    Enabled = False
End Sub

Public Sub chkFull_OnGetPressed(ByRef control As IRibbonControl, ByRef pressed As Variant)
    pressed = chkFull_Pressed
End Sub

Public Sub chkMini_OnAction(ByRef control As IRibbonControl, ByRef pressed As Boolean)
    'TODO:
End Sub
Public Sub chkMini_OnGetEnabled(ByRef control As IRibbonControl, ByRef Enabled As Variant)
    Enabled = False
End Sub
Public Sub chkMini_OnGetPressed(ByRef control As IRibbonControl, ByRef pressed As Variant)
    pressed = chkMini_Pressed
End Sub

Public Sub chkNone_OnAction(ByRef control As IRibbonControl, ByRef pressed As Boolean)
    'TODO:
End Sub
Public Sub chkNone_OnGetEnabled(ByRef control As IRibbonControl, ByRef Enabled As Variant)
    Enabled = False
End Sub
Public Sub chkNone_OnGetPressed(ByRef control As IRibbonControl, ByRef pressed As Variant)
    pressed = chkNone_Pressed
End Sub







'****************************************************************************************
'               Extra Functions
'****************************************************************************************

Public Sub IterPrintRoutines()
    'rtCombo_TextField
    'runRoutineList
    For i = 0 To UBound(runRoutineList, 2)
        rtCombo_TextField = runRoutineList(0, i)
        lblStatus_Text = runRoutineList(1, i)
        
        Call SetVariabes
        Call SetWorkbookInformation
        Call ThisWorkbook.PrintResults
    Next i
    
    cusRibbon.InvalidateControl "rtCombo"
    cusRibbon.InvalidateControl "jbEditText"
    cusRibbon.InvalidateControl "lblStatus"
    
End Sub


Function JoinPivotFeatures(featureHeaderInfo() As Variant) As String
    Dim paramFeatures() As String
    ReDim Preserve paramFeatures(UBound(featureHeaderInfo, 2))
    For i = 0 To UBound(featureHeaderInfo, 2)
        paramFeatures(i) = "[" & featureHeaderInfo(0, i) & "]"
    Next i
    
    JoinPivotFeatures = Join(paramFeatures, ",")

End Function

Private Sub SetVariabes()
    featureHeaderInfo = DatabaseModule.GetFeatureHeaderInfo(jobNum:=jobNumUcase, routine:=rtCombo_TextField)
    If toggShowAllObs_Pressed Then
        featureMeasuredValues = DatabaseModule.GetAllFeatureMeasuredValues(jobNum:=jobNumUcase, routine:=rtCombo_TextField, _
                                                delimFeatures:=JoinPivotFeatures(featureHeaderInfo))
        featureTraceabilityInfo = DatabaseModule.GetAllFeatureTraceabilityData(jobNum:=jobNumUcase, routine:=rtCombo_TextField)
    Else
        featureMeasuredValues = DatabaseModule.GetFeatureMeasuredValues(jobNum:=jobNumUcase, routine:=rtCombo_TextField, _
                                                delimFeatures:=JoinPivotFeatures(featureHeaderInfo), featureInfo:=featureHeaderInfo)
        featureTraceabilityInfo = DatabaseModule.GetFeatureTraceabilityData(jobNum:=jobNumUcase, routine:=rtCombo_TextField)
    End If

End Sub

Private Sub ClearVariables(Optional preserveRoutines As Boolean)
    
    'Always
        'When the we try to set feature info w/o any info the wb runs cleanup and then stops
    rtCombo_TextField = ""
    lblStatus_Text = ""
    Erase featureHeaderInfo
    Erase featureMeasuredValues
    Erase featureTraceabilityInfo
    
    
    If preserveRoutines Then Exit Sub
    
    'Sometimes
        'Want to skip this (likely because user entered nonsense into the routineName box)
    
    rtCombo_Enabled = False
    jobNumUcase = UCase(Text)
    chkFull_Pressed = False
    chkMini_Pressed = False
    chkNone_Pressed = False
    
    'Keep Job Info
    partNum = vbNullString
    rev = vbNullString
    customer = vbNullString
    machine = vbNullString
    cell = vbNullString
    partDesc = vbNullString
    
    'Keep routines for ComboBox
    Erase partRoutineList
    Erase runRoutineList


End Sub

Private Sub SetWorkbookInformation()
    Call ThisWorkbook.populateJobHeaders(jobNum:=jobNumUcase, routine:=rtCombo_TextField, customer:=customer, _
                                            machine:=machine, partNum:=partNum, rev:=rev, partDesc:=partDesc)
    Call ThisWorkbook.populateReport(featureInfo:=featureHeaderInfo, featureMeasurements:=featureMeasuredValues, _
                                        featureTraceability:=featureTraceabilityInfo)

End Sub

