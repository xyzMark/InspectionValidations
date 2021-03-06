VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} VettingForm 
   Caption         =   "MeasurLink Routine Vetting"
   ClientHeight    =   8205.001
   ClientLeft      =   120
   ClientTop       =   450
   ClientWidth     =   7260
   OleObjectBlob   =   "VettingForm.frx":0000
   StartUpPosition =   1  'CenterOwner
End
Attribute VB_Name = "VettingForm"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
'*************************************************************************************************
'
'   Vetting Form
'       1. Everything happens in _Initialize(),
'           We set the Routine, ObsReq and ObsFound in the respesctive routines
'           As we go through the routines for the part number, we set the name and make the text gray
'           When we find a routine of the same name that we ran for that job number, we fill it black to indicate a match
'           A routine being gray doesn't auto indicate a failure, it might depend on the job type
'*************************************************************************************************


Option Compare Text

Dim cellLeadAlertReq As Boolean
Dim qcManagerAlertReq As Boolean
Dim pmodManagerAlertReq As Boolean
Dim failedRoutines() As Variant
Dim aqlQuantity As String



Private Sub Label42_Click()

End Sub

Private Sub Routine1_Click()

End Sub

'****************************************************************************************
'               UserForm Callbacks
'****************************************************************************************

Private Sub UserForm_Initialize()
    
    Call SetActivePrinter
    
    Me.ProdQty.Caption = format(RibbonCommands.ProdQty, "#,###")

    'Set the required routines for the part
    'Also set the required observations for the routine
    For i = 0 To UBound(RibbonCommands.partRoutineList, 2)
        With Me.RoutineFrame.Controls(i)
            .Caption = RibbonCommands.partRoutineList(0, i) 'set all of the routines that COULD be applicable
            .ForeColor = RGB(128, 128, 128)
            .Visible = True
        End With
        With Me.ObsFound.Controls(i)
            .Caption = ""
            .Visible = False
        End With
        With Me.ObsReq.Controls(i)
        
            On Error GoTo RoutineNameErr
            
            Dim routineCreated As Boolean
            Dim routineIndex As Integer
            Dim fullRoutine As String
            Dim routineType As String
                        
            fullRoutine = RibbonCommands.partRoutineList(0, i)
            routineType = Split(RibbonCommands.partRoutineList(0, i), RibbonCommands.partNum & "_" & RibbonCommands.rev & "_")(1) 'Get "FA_FIRST" for example
            routineIndex = RibbonCommands.GetRoutineIndex(fullRoutine) 'If we didnt create a routine of that name, then this returns 99
            If routineIndex < 99 Then
                routineCreated = True
            Else
                routineCreated = False
            End If
            On Error GoTo RoutineSwitchErr
            
            
            'FA and IP routines (machining)
            If (InStr(routineType, "FA_") > 0) Or (InStr(routineType, "IP_") > 0) Then
                'Specially Handle Child Jobs. Only an FA_FIRST requires inspections
                
                'NextObsReq
                If RibbonCommands.IsChildJob Then
                    If (InStr(routineType, "FIRST") > 0) Then
                        .Caption = "1"
                        .Visible = True
                    Else
                        .Caption = "0"
                        .Visible = False
                    End If
                
                    GoTo NextObsReq
                End If
                
                Dim level As Integer
                Dim setupType As String
                If (Not routineCreated) Then 'If the routine wasnt created
                    level = GetMachiningLevel(fullRoutine)
                    If (RibbonCommands.machineStageMissing And Not Not (RibbonCommands.missingLevels)) Then 'Becuase we have missing machining operations
                        If IsNumeric(Application.Match(level, RibbonCommands.missingLevels, 0)) Then 'Like the one this routine would have belonged to
                            .Visible = False
                            .Caption = "0"
                            GoTo NextObsReq 'Set no requirement, go to the next one
                        Else
                            GoTo ShouldExist
                        End If
                    Else
ShouldExist:
                       'Someone maybe should have created this routine but didnt, we wont know for sure until we have the setup type
                       For j = 0 To UBound(jobOperations, 2)
                        If (partOperations(1, level) = jobOperations(4, j)) And (partOperations(2, level) = jobOperations(5, j)) Then
                            'If the Op# and Op Codes Match, grab the setup type from the matched level
                             setupType = jobOperations(1, j)
                            GoTo 10
                        End If
                    Next j
                    End If
                Else
                    setupType = RibbonCommands.runRoutineList(3, routineIndex) 'If the routine does exist, just grab the setup type info
                End If
'FA and IP Routines
10
                If (InStr(routineType, "FIRST") > 0) Then
                    If (setupType = "Full") Then
                        .Caption = "2"
                        .Visible = True
                    Else
                        .Caption = "0"
                        .Visible = False
                    End If
                    
                ElseIf (InStr(routineType, "FA_SYLVAC") > 0 Or InStr(routineType, "FA_CMM") > 0 Or InStr(routineType, "FA_RAMPROG") > 0) Then
                    If (setupType = "Full") Then
                        .Caption = "1"
                        .Visible = True
                    Else
                        .Caption = "0"
                        .Visible = False
                    End If
                    
                ElseIf (InStr(routineType, "FA_MINI") > 0) Then
                    If (setupType = "Mini") Then
                        .Caption = "2"
                        .Visible = True
                    Else
                        .Caption = "0"
                        .Visible = False
                    End If
                    
                ElseIf (InStr(routineType, "FA_VIS") > 0) Then
                    If (setupType = "None") Then
                        .Caption = "2"
                        .Visible = True
                    Else
                        .Caption = "0"
                        .Visible = False
                    End If
                    
                ElseIf (InStr(routineType, "IP_1XSHIFT") > 0) Then
                    level = GetMachiningLevel(fullRoutine)
                    .Caption = DatabaseModule.Get1XSHIFTInsps(JobID:=RibbonCommands.jobNumUcase, Operation:=RibbonCommands.partOperations(1, level))
                    .Visible = True
                
                ElseIf (InStr(routineType, "IP_EDM") > 0) Then
                    .Caption = RibbonCommands.ProdQty
                    .Visible = True
                
                ElseIf (InStr(routineType, "IP_LAST") > 0) Then
                    .Caption = "1"
                    .Visible = True
                
                Else
                    'Anything not covered above should be AQL quantity, and is likely an IP Routine
                    If RibbonCommands.IsParentJob Then  'Parent jobs should have AQL based off parts made, not just what we have
                        .Caption = GetRequiredInspections(customer:=RibbonCommands.customer, drawNum:=RibbonCommands.drawNum, _
                                                ProdQty:=DatabaseModule.GetParentProdQty(JobNumber:=RibbonCommands.jobNumUcase), routineType:=routineType)
                    Else
                        .Caption = GetRequiredInspections(customer:=RibbonCommands.customer, drawNum:=RibbonCommands.drawNum, _
                                                ProdQty:=RibbonCommands.ProdQty, routineType:=routineType)
                    
                    End If
                    .Visible = True
                End If
                
'FI Routines
            ElseIf InStr(routineType, "FI_") > 0 Then
                If (InStr(routineType, "FI_VIS") > 0) Then
                    .Caption = "1"
                    .Visible = True
                ElseIf (InStr(routineType, "FI_DIM") > 0) Or (InStr(routineType, "FI_OP") > 0) Then
                    'FI_DIMs will usually need AQL requirements but if all features are attribute then its possible we only need one
                    If DatabaseModule.IsAllAttribrute(routine:=RibbonCommands.partRoutineList(0, i)) Then
                        .Caption = "1"
                    Else
                        .Caption = GetRequiredInspections(customer:=RibbonCommands.customer, drawNum:=RibbonCommands.drawNum, _
                                        ProdQty:=RibbonCommands.ProdQty, routineType:=routineType)
                        
                    End If
                    .Visible = True
'                ElseIf (InStr(routineType, "FI_OP") > 0) Then
'                    .Caption = GetAQL(customer:=RibbonCommands.customer, drawNum:=RibbonCommands.drawNum, _
'                                            ProdQty:=RibbonCommands.ProdQty)
'                    .Visible = True
                Else
                End If
            Else
                GoTo RoutineSwitchErr
            End If
            
NextObsReq:
        End With
    Next i
    
    On Error GoTo 0
    
    'Hide and reset the excess controls
    For i = i To Me.RoutineFrame.Controls.Count - 1
        Me.RoutineFrame.Controls(i).Visible = False
        Me.RoutineFrame.Controls(i).Caption = ""
        Me.ObsReq.Controls(i).Visible = False
        Me.ObsReq.Controls(i).Caption = ""
        Me.ObsFound.Controls(i).Visible = False
        Me.ObsFound.Controls(i).Caption = ""
        Me.ResultFrame.Controls(i).Visible = False
    Next i
    
    'Fill the required routines with the routines that we found in the run
    'Also fill in the observations that we have collected
    If (Not Not RibbonCommands.runRoutineList) Then
        For i = 0 To UBound(RibbonCommands.runRoutineList, 2)
            For j = 0 To Me.RoutineFrame.Count - 1
                'If the control name matches the found routine name, then we should make the text black and fill in the observations found
                If (RibbonCommands.runRoutineList(0, i) = Me.RoutineFrame.Controls(j).Caption) Then
                    Me.RoutineFrame.Controls(j).ForeColor = RGB(0, 0, 0)
                    Me.ObsFound.Controls(j).Caption = runRoutineList(2, i)
                    Me.ObsFound.Controls(j).Visible = True
                    GoTo NextControl
                End If
            Next j
            'If we couldnt find a match between required routines and the run routine
            GoTo UniqueRoutineErr
NextControl:
        Next i
    End If
    
    
    Call VetInspections
    
    If (cellLeadAlertReq Or qcManagerAlertReq Or pmodManagerAlertReq) Then
        Me.PrintButton.Enabled = False
        Me.EmailButton.Enabled = True
        Me.EmailButton.SetFocus
    Else
        Me.PrintButton.Enabled = True
        Me.EmailButton.Enabled = False
        Me.PrintButton.SetFocus
    End If
    
    Exit Sub
    
RoutineNameErr:
   result = MsgBox("Could Not Parse the Routine Name " & RibbonCommands.partRoutineList(0, i) & _
                vbCrLf & "Alert a QE" & _
                vbCrLf & "Routines Must Follow the standard naming convention of [Part]_[Rev]_[OPtype]_[Routine SubType]", vbExclamation)
    Exit Sub

UniqueRoutineErr:
   result = MsgBox("Application found this routine: " & RibbonCommands.runRoutineList(0, i) & _
                vbCrLf & "Which doesn't match any of our required routines" & _
                vbCrLf & "If a routine name changed, it could cause misalignment here", vbInformation)
   GoTo NextControl

RoutineSwitchErr:
       result = MsgBox("Error when determining observations needed for : " & RibbonCommands.partRoutineList(0, i) & vbCrLf & _
                 "UserForm Init" & vbCrLf & Err.Description, vbCritical)

End Sub


Private Sub EmailButton_Click()
    Dim cells() As Variant
    Dim machines() As Variant
    
    'If there are no machining operations required, then we dont need to query for a machine name
    If ((Not RibbonCommands.jobOperations) = -1) Then
        ReDim Preserve machines(0)
        machines(0) = "[Outsourced Machining]"
        GoTo 10
    End If
    
    For i = 0 To UBound(failedRoutines, 2)
        Dim level As Integer
        level = RibbonCommands.GetMachiningLevel(failedRoutines(0, i))
        For j = 0 To UBound(RibbonCommands.jobOperations, 2)
            'Determine what machining op the routine should belong to, and pull its machine and cell data
            If ((RibbonCommands.partOperations(1, level) = RibbonCommands.jobOperations(4, j)) _
                And RibbonCommands.partOperations(2, level) = RibbonCommands.jobOperations(5, j)) Then
                    Dim machine As String
                    Dim cell As String
                    machine = RibbonCommands.jobOperations(2, j)
                    cell = RibbonCommands.jobOperations(3, j)
                    
                    'Add to our list of machines and cells responsible for the failures
                    If ((Not cells) = -1 And (Not machines) = -1) Then
                        ReDim Preserve cells(0)
                        ReDim Preserve machines(0)
                        cells(0) = cell
                        machines(0) = machine
                    Else
                        If Not (IsNumeric(Application.Match(cell, cells, 0))) Then 'If the cell is not already in our list of cells, add it
                            ReDim Preserve cells(UBound(cells) + 1)
                            cells(UBound(cells)) = cell
                        End If
                        If Not (IsNumeric(Application.Match(machine, machines, 0))) Then 'If the machines is not already in our list of machines, add it
                            ReDim Preserve machines(UBound(machines) + 1)
                            machines(UBound(machines)) = machine
                        End If
                    End If
                    GoTo Nexti
            End If
        Next j
      'If we made it here then our routine's Level is higher then we machined
      'In theory the only reason this should ever occur is becuase we have a failed FI routine for a multiple operation part and we
        'outsourced the final machining operation
        If ((Not cells) = -1 And (Not machines) = -1) Then
            ReDim Preserve cells(0)
            ReDim Preserve machines(0)
            cells(0) = "QC"
            machines(0) = "QC"
        Else
            If Not (IsNumeric(Application.Match("QC", cells, 0))) Then
                ReDim Preserve cells(UBound(cells) + 1)
                cells(UBound(cells)) = "QC"
            End If
            If Not (IsNumeric(Application.Match("QC", machines, 0))) Then
                ReDim Preserve machines(UBound(machines) + 1)
                machines(UBound(machines)) = "QC"
            End If
        End If
        
Nexti:
    Next i

    Dim cellLeadEmail As String
    For i = 0 To UBound(cells)
        cellLeadEmail = cellLeadEmail & DatabaseModule.GetCellLeadEmail(cell:=cells(i)) & ";"
    Next i
10
    Dim machineList As String
    For i = 0 To UBound(machines)
        machineList = machineList & machines(i)
        If i <> UBound(machines) Then machineList = machineList & ","
    Next i
        
    Call ExcelHelpers.CreateEmail(qcManager:=qcManagerAlertReq, pmodManager:=pmodManagerAlertReq, cellLead:=cellLeadAlertReq, cellLeadEmail:=cellLeadEmail, _
                                    jobnum:=RibbonCommands.jobNumUcase, machine:=machineList, failInfo:=failedRoutines)

End Sub

Private Sub PrintButton_Click()
    Unload Me
    Call RibbonCommands.IterPrintRoutines
End Sub



Private Sub ChangePrinterButton_Click()
    If (Application.Dialogs(xlDialogPrinterSetup).Show) Then
        Call SetActivePrinter
    End If
End Sub

Private Sub ForcePrintButton_Click()
    'Override locking out our users from printing when routines fail
    Dim result As String
    result = Me.PasswordTextBox.Text
    
    If result = DataSources.ENABLE_PRINTING_PASS Then
        Me.PrintButton.Enabled = True
        Me.ForcePrintButton.Enabled = False
        MsgBox ("Printing Enabled")
    Else
        result = MsgBox("Incorrect Password", vbCritical)
        
    End If
    
    Me.PasswordTextBox.Text = vbNullString


End Sub




'****************************************************************************************
'               Extra Functions
'****************************************************************************************
Private Sub VetInspections()
    
    For i = 0 To Me.RoutineFrame.Controls.Count - 1
        'If there is a Req Qty and a Found Qty
        If (Me.ObsReq.Controls(i).Visible = True And Me.ObsFound.Controls(i).Visible = True) Then
            'If our Found Qty meets our criteria
            If (CInt(Me.ObsFound.Controls(i).Caption) >= CInt(Me.ObsReq.Controls(i).Caption)) Then
                GoTo NextIter
            'If it doesn't meet our criteria
            Else
                Call setFailure(location:=i, routine:=Me.RoutineFrame.Controls(i).Caption)
                GoTo NextIter
            End If
        'If we have Req Qty but didn't find results for inspected Qty
        ElseIf Me.ObsReq.Controls(i).Visible = True And Me.ObsFound.Controls(i).Visible = False Then
            Call setFailure(location:=i, routine:=Me.RoutineFrame.Controls(i).Caption)
            GoTo NextIter
        'If we have a routine but no Req Qty because the setup type doesn't require it, not considered a failure
        ElseIf (Me.RoutineFrame.Controls(i).Visible = True And Me.ObsReq.Controls(i).Visible = False) Then
            Call hideResult(location:=i)
            'If we have a routine created that wasn't needed, strikethrough the text
            If Me.ObsReq.Controls(i).Visible = False And Me.ObsFound.Controls(i).Visible = True Then
                Me.RoutineFrame.Controls(i).Font.Strikethrough = True
            End If
            GoTo NextIter
        'If its a hidden control
        ElseIf Me.RoutineFrame.Controls(i).Visible = False Then
        Else
            GoTo RoutineReadErr
        End If
        
NextIter:
    Next i
    
    Exit Sub
    
RoutineReadErr:

   result = MsgBox("Could not correctly compare the quantities of " & Me.RoutineFrame.Controls(i).Caption & _
                    vbCrLf & "Please alert a QE to this.", vbExclamation)

End Sub


Private Sub setFailure(location As Variant, routine As String)
    'Set failure picture
    With Me.ResultFrame.Controls(location)
        .Picture = LoadPicture(DataSources.FAIL_IMG_PATH)
        .Height = 15
        .Width = 15
        .Top = .Top + 4
    
    End With
    
    'If there was a problem with and 'FI' Routine like 'FI_DIM' then we need to alert the QC manager, otherwise we need to alert the cell lead
    Dim routineSuffix As String
    routineSuffix = Split(routine, RibbonCommands.partNum & "_" & RibbonCommands.rev & "_")(1)
    If (InStr(routineSuffix, "FI") > 0) Then
        qcManagerAlertReq = True
    ElseIf (InStr(routineSuffix, "IP_ASSY") > 0) Then
        pmodManagerAlertReq = True
    Else
        cellLeadAlertReq = True
    End If
    
    'Store the failed results for later passing to the email
    Dim index As Integer
        'Checks if the array has ever been initialized
    If (Not failedRoutines) = -1 Then
        index = 0
        ReDim Preserve failedRoutines(2, 0)
    Else
        index = UBound(failedRoutines, 2) + 1
        ReDim Preserve failedRoutines(2, index)
    End If
    
    failedRoutines(0, index) = Me.RoutineFrame(location).Caption
    failedRoutines(1, index) = Me.ObsReq(location).Caption
    failedRoutines(2, index) = Me.ObsFound(location).Caption
    
End Sub

Private Sub hideResult(location As Variant)
    Me.ResultFrame.Controls(location).Visible = False
End Sub

Private Sub SetActivePrinter()
    Me.ActivePrinter.Caption = Split(Application.ActivePrinter, " ")(0)

End Sub

Private Sub SetAQLHeader(AQL As String)
    Me.AQL.Caption = AQL
End Sub

    'Wrapper for ExcelHelper.GetAQL()
    'stores the values that we find in RibbonCommands reduce redundant queries
Private Function GetRequiredInspections(customer As String, drawNum As String, ProdQty As Integer, routineType As String) As String
    If (RibbonCommands.samplingSize = vbNullString And RibbonCommands.custAQL = vbNullString) Or RibbonCommands.IsParentJob Then
        Dim aqlValues() As String
        aqlValues = ExcelHelpers.GetAQL(customer:=customer, drawNum:=drawNum, ProdQty:=ProdQty, isShortRunEnabled:=RibbonCommands.isShortRunEnabled)
        
        RibbonCommands.samplingSize = aqlValues(0)
        RibbonCommands.custAQL = aqlValues(1)
        
        If RibbonCommands.custAQL = "100%" Then
            Me.AQL.Caption = "100%"
        Else
            Me.AQL.Caption = format(RibbonCommands.custAQL, "0.00")
        End If
        
        On Error GoTo LowerBoundErr
        
        If RibbonCommands.isShortRunEnabled Then   'We should have pulled the Cutoff values as well
            RibbonCommands.lowerBoundCutoff = CInt(aqlValues(2))
            RibbonCommands.lowerBoundInspections = CInt(aqlValues(3))
        End If
        
        
        If RibbonCommands.isShortRunEnabled And Not routineType Like "*FI_*" Then
            If ProdQty <= RibbonCommands.lowerBoundCutoff Then
                GetRequiredInspections = CStr(RibbonCommands.lowerBoundInspections)
            Else
                GetRequiredInspections = aqlValues(0)
            End If
        Else
            GetRequiredInspections = aqlValues(0)
        End If
        
    Else
        If RibbonCommands.custAQL = "100%" Then
            Me.AQL.Caption = "100%"
        Else
            Me.AQL.Caption = format(RibbonCommands.custAQL, "0.00")
        End If
        
        On Error GoTo LowerBoundErr
        
        If RibbonCommands.isShortRunEnabled And Not routineType Like "*FI_*" Then
            If ProdQty <= RibbonCommands.lowerBoundCutoff Then
                GetRequiredInspections = CStr(RibbonCommands.lowerBoundInspections)
            Else
                GetRequiredInspections = RibbonCommands.samplingSize
            End If
        Else
            GetRequiredInspections = RibbonCommands.samplingSize
        End If
        
    End If
    
    Exit Function
    
    
LowerBoundErr:
    MsgBox "Encountered an Error with handling the Lower Boundary Frequency values set in the Inspection Report" _
                & vbCrLf & "Please have a QE make sure the Values in the IR are correct", vbCritical

End Function








