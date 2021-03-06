Attribute VB_Name = "DatabaseModule"

'*************************************************************************************************
'
'   DataBase Module
'      Public functions should generate their queries and parameters, then call the private subroutines....
'           1. Init_Connections()
'           2. ExecQuery()
'           3. GetConnection()
'           4. Close_Connections()
'
'       Public functions then return the data to the caller in Variant Array form using .GetRows() on the sqlRecordSet
'
'*************************************************************************************************

Option Compare Text

Private E10DataBaseConnection As ADODB.Connection
Private ML7DataBaseConnection As ADODB.Connection
Private KioskDataBaseConnection As ADODB.Connection
Private sqlCommand As ADODB.Command
Private sqlRecordSet As ADODB.Recordset
Dim fso As New FileSystemObject
Dim query As String
Dim params() As Variant

Private Enum Connections
    E10 = 0
    ML7 = 1
    Kiosk = 2
End Enum


Sub Init_Connections()

    On Error GoTo Err_Conn
    
    If ML7DataBaseConnection Is Nothing Then
        
        Set ML7DataBaseConnection = New ADODB.Connection
        If RibbonCommands.toggML7TestDB_Pressed Then
            ML7DataBaseConnection.ConnectionString = DataSources.ML7TEST_CONN_STRING
        Else
            ML7DataBaseConnection.ConnectionString = DataSources.ML7_CONN_STRING
        End If
        
        ML7DataBaseConnection.Open
    End If
      
    If E10DataBaseConnection Is Nothing Then
        Set E10DataBaseConnection = New ADODB.Connection
        E10DataBaseConnection.ConnectionString = DataSources.E10_CONN_STRING
        E10DataBaseConnection.Open
    End If
    
    If KioskDataBaseConnection Is Nothing Then
        Set KioskDataBaseConnection = New ADODB.Connection
        KioskDataBaseConnection.ConnectionString = DataSources.KIOSK_CONN_STRING
        KioskDataBaseConnection.Open
    End If
    
    On Error GoTo 0
       
        
    Exit Sub
    
Err_Conn:
    Err.Raise Number:=Err.Number, Description:="There was an error connecting with the Epicor and/or MeasurLink Database " _
        & "you may not be connected to the Network or you may not have permission from the Administrator to read from the MeasurLink DataBase"

End Sub

    'Calling function should pass us a query and array of parameters to set
    'In this sub we should execute the query and set the topLevel recordset that the calling function can use GetRows() on
Private Sub ExecQuery(query As String, params() As Variant, conn_enum As Connections)

    Call Init_Connections
    Set fso = New FileSystemObject

    On Error GoTo QueryFailed

    Set sqlCommand = New ADODB.Command
    With sqlCommand
        .ActiveConnection = GetConnection(conn_enum)
        .CommandType = adCmdText
        .CommandText = query
    
        'Params structure
        'params(0) = "jh.JoNum,'NV1452'"
        For i = 0 To UBound(params)
            Dim queryParam As ADODB.Parameter
            Set queryParam = .CreateParameter(Name:=Split(params(i), ",")(0), Type:=adVarChar, Size:=255, Direction:=adParamInput, Value:=Split(params(i), ",")(1))
            .Parameters.Append queryParam
        Next i
    
    End With
    
    Set sqlRecordSet = New ADODB.Recordset
    sqlRecordSet.Open sqlCommand

    On Error GoTo 0

    If sqlRecordSet.EOF Then
        Err.Raise Number:=vbObjectError + 2000, Description:="sub:ExecQuery, no results"
        'Returning no rows is not technically an error, let the calling function handle this
    End If
    
    Exit Sub
    
QueryFailed:
    Err.Raise Number:=vbObjectError + 3000, Description:="sub:ExecQuery - params" & vbCrLf & Join(params, vbCrLf) & vbCrLf & Err.Description
    
End Sub



Private Function GetConnection(conn_enum As Connections) As ADODB.Connection
    Select Case conn_enum
        Case 0
            Set GetConnection = E10DataBaseConnection
        Case 1
            Set GetConnection = ML7DataBaseConnection
        Case 2
            Set GetConnection = KioskDataBaseConnection
        Case Else
    End Select
End Function


Sub Close_Connections()
    If Not (ML7DataBaseConnection Is Nothing) Then ML7DataBaseConnection.Close
    If Not (E10DataBaseConnection Is Nothing) Then E10DataBaseConnection.Close
    If Not (KioskDataBaseConnection Is Nothing) Then KioskDataBaseConnection.Close
End Sub







'*************************************************************************************************
'
'  Public Functions By Database
'
'*************************************************************************************************




''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'               Epicor
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Function GetJobInformation(JobID As String) As Variant()
    
    Set fso = New FileSystemObject
    params = Array("ld.JobNum," & JobID, "jh.JobNum," & JobID)
    query = fso.OpenTextFile(DataSources.QUERIES_PATH & "EpicorJobInfo.sql").ReadAll
    
    
    On Error GoTo JobInfoErr:
    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.E10)
    
    GetJobInformation = sqlRecordSet.GetRows()
    Exit Function
    
    
JobInfoErr:
    'if errored because recordset.EOF, then pass back to RibbonCommands and let it handle this
    If Err.Number = vbObjectError + 2000 Then
        Err.Raise Number:=vbObjectError + 2000, Description:="Job Does Not Exist" & vbCrLf & Err.Description
    Else
        Err.Raise Number:=Err.Number, Description:="Func: E10-GetJobInformation" & vbCrLf & Err.Description
    End If
End Function


Function Get1XSHIFTInsps(JobID As String, Operation As Variant) As String
    On Error GoTo ShiftERR
    Set fso = New FileSystemObject
    params = Array("jo.JobNum," & JobID, "jo.OprSeq," & Operation)
    query = fso.OpenTextFile(DataSources.QUERIES_PATH & "1XSHIFT.sql").ReadAll

    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.E10)
    
    Get1XSHIFTInsps = sqlRecordSet.Fields(1).Value
    Exit Function
    
ShiftERR:
    If Err.Number = vbObjectError + 2000 Then
        Get1XSHIFTInsps = "0"  'Technically, if we didnt run any shifts, we dont owe any inspections
        Exit Function
    Else
        Err.Raise Number:=Err.Number, Description:="Func: E10-Get1XSHIFTInsps" & vbCrLf & Err.Description
    End If
    
End Function

Function GetPartOperationInfo(JobID As String) As Variant()
    On Error GoTo PartOpErr
    Set fso = New FileSystemObject
    params = Array("jh.JobNum," & JobID)
    query = fso.OpenTextFile(DataSources.QUERIES_PATH & "EpicorPartOpInfo.sql").ReadAll

    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.E10)
    
    GetPartOperationInfo = sqlRecordSet.GetRows()
    Exit Function
    
PartOpErr:
    If Err.Number = vbObjectError + 2000 Then
        Dim emptyArr() As Variant
        GetPartOperationInfo = emptyArr 'Its possible that a part is strictly made outside, see IN0001 integrity springs
        Exit Function
    Else
        Err.Raise Number:=Err.Number, Description:="Func: E10-GetPartOpInfo" & vbCrLf & Err.Description
    End If
    
End Function

Function GetJobOperationInfo(JobID As String) As Variant()
    On Error GoTo JobOpErr
    Set fso = New FileSystemObject
    params = Array("jh.JobNum," & JobID)
    query = fso.OpenTextFile(DataSources.QUERIES_PATH & "EpicorOperationInfo.sql").ReadAll

    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.E10)
    
    GetJobOperationInfo = sqlRecordSet.GetRows()
    Exit Function
    
JobOpErr:
    If Err.Number = vbObjectError + 2000 Then
        Dim emptyArr() As Variant
        GetJobOperationInfo = emptyArr 'Part didnt actually get machined at all in house
        Exit Function
    Else
        Err.Raise Number:=Err.Number, Description:="Func: E10-GetJobOpInfo" & vbCrLf & Err.Description
    End If

End Function

Function IsParentJob(JobNumber As String) As Boolean
    On Error GoTo ParentJobErr
    Set fso = New FileSystemObject
    params = Array("jh.JobNum," & JobNumber, "child.JobNum," & JobNumber)
    query = fso.OpenTextFile(DataSources.QUERIES_PATH & "EpicorParentJob.sql").ReadAll

    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.E10)
    
    If UBound(sqlRecordSet.GetRows(), 2) > 0 Then IsParentJob = True  'If there is more than one row, then its a parent
    
    Exit Function
    
ParentJobErr:
      'If Empty maybe JobNumber doesnt exist, but we did make
    Err.Raise Number:=Err.Number, Description:="Func: E10-IsParentJob" & vbCrLf & Err.Description

End Function

    'Sum of all parts produced in primary operation. Exclude Job Adjustments
Function GetParentProdQty(JobNumber As String) As Integer
    On Error GoTo ParentProdQty
    Set fso = New FileSystemObject
    params = Array("ld.JobNum," & JobNumber, "jo.JobNum," & JobNumber)
    query = fso.OpenTextFile(DataSources.QUERIES_PATH & "EpicorParentProdQty.sql").ReadAll

    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.E10)
    
    GetParentProdQty = sqlRecordSet.Fields(0).Value
       
    Exit Function
    
ParentProdQty:
   'Job Number must not exist
    Err.Raise Number:=Err.Number, Description:="Func: E10-GetParentProdQty" & vbCrLf & Err.Description

End Function




''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'               MeasurLink
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

Function GetFeatureHeaderInfo(jobnum As String, routine As String) As Variant()
    On Error GoTo FeatureHeaderErr
    Set fso = New FileSystemObject
    query = fso.OpenTextFile(DataSources.QUERIES_PATH & "ML_FeatureHeaderInfo.sql").ReadAll
    params = Array("r.RunName," & jobnum, "rt.RoutineName," & routine)
    
    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.ML7)
    
    GetFeatureHeaderInfo = sqlRecordSet.GetRows()
    Exit Function
    
FeatureHeaderErr:
    If Err.Number = vbObjectError + 2000 Then
        Err.Raise Number:=Err.Number, Description:="Func: ML7-GetFeatureHeaderInfo" & vbCrLf & Err.Description & vbCrLf _
                & "There may not be GaugeID's entered for " & routine
    Else
        Err.Raise Number:=Err.Number, Description:="Func: ML7-GetFeatureHeaderInfo" & vbCrLf & Err.Description
    End If
End Function

    'Get observation values, filter out failures
Function GetFeatureMeasuredValues(jobnum As String, routine As String, delimFeatures As String, featureInfo() As Variant, Optional IS_FI_DIM As Boolean) As Variant()

    On Error GoTo FeatureValuesErr
    Set fso = New FileSystemObject
    query = Replace(Split(fso.OpenTextFile(DataSources.QUERIES_PATH & "ML_FeatureMeasurements.sql").ReadAll, ";")(0), "{Features}", delimFeatures)
    
    Dim whereClause As String
    For i = 0 To UBound(featureInfo, 2)
        If featureInfo(6, i) = "Attribute" Then
            If IS_FI_DIM Then GoTo nextFeat
        
            'Filter out Attribute failures by column
            whereClause = whereClause & "(Pvt.[" & featureInfo(0, i) & "] <> 1 AND Pvt.[" & featureInfo(0, i) & "] IS NOT NULL)"
        Else
            'Filter out Variable failure by column
            whereClause = whereClause & "(Pvt.[" & featureInfo(0, i) & "] <> 99.998 AND Pvt.[" & featureInfo(0, i) & "] IS NOT NULL)"
        End If
        'if its the last statement, no need for the AND
        If i <> UBound(featureInfo, 2) Then
            whereClause = whereClause & " AND "
        End If
nextFeat:
    Next i
    
        'Need to trim off the hanging AND in the event of FI_DIM
        If IS_FI_DIM And featureInfo(6, UBound(featureInfo, 2)) = "Attribute" Then
            whereClause = Left(whereClause, Len(whereClause) - 4)
        End If
    
    

    query = query & whereClause
    Debug.Print (query)
    params = Array("r.RunName," & jobnum, "rt.RoutineName," & routine, "r.RunName," & jobnum, "rt.RoutineName," & routine)
    
    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.ML7)

    GetFeatureMeasuredValues = sqlRecordSet.GetRows()
    Exit Function

FeatureValuesErr:
    If Err.Number = vbObjectError + 2000 Then
        Dim emptyArr() As Variant
        GetFeatureMeasuredValues = emptyArr
        Exit Function
    Else
        Err.Raise Number:=Err.Number, Description:="Func: ML7-GetFeatureMeasuredValues" & vbCrLf & Err.Description
    End If
End Function

    'Get all observation values, don't filter
Function GetAllFeatureMeasuredValues(jobnum As String, routine As String, delimFeatures As String) As Variant()
    On Error GoTo AllFeatureValuesErr
    Set fso = New FileSystemObject
    query = Replace(Split(fso.OpenTextFile(DataSources.QUERIES_PATH & "ML_FeatureMeasurements.sql").ReadAll, ";")(1), "{Features}", delimFeatures)
    params = Array("r.RunName," & jobnum, "rt.RoutineName," & routine, "r.RunName," & jobnum, "rt.RoutineName," & routine)
    
    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.ML7)

    GetAllFeatureMeasuredValues = sqlRecordSet.GetRows()
    Exit Function
    
AllFeatureValuesErr:
    If Err.Number = vbObjectError + 2000 Then
        Dim emptyArr() As Variant
        GetAllFeatureMeasuredValues = emptyArr
        Exit Function
    Else
        Err.Raise Number:=Err.Number, Description:="Func: ML7-GetAllFeatureMeasuredValues" & vbCrLf & Err.Description
    End If
End Function

    'Date, Employee ID - Filter out failed observations
Function GetFeatureTraceabilityData(jobnum As String, routine As String, Optional FI_DIM_ROUTINE As Boolean) As Variant()
    On Error GoTo FeatureTraceabilityErr
    Set fso = New FileSystemObject
    
    If FI_DIM_ROUTINE Then
        query = Split(fso.OpenTextFile(DataSources.QUERIES_PATH & "ML_ObsTraceability.sql").ReadAll, ";")(2)
        params = Array("r.RunName," & jobnum, "rt.RoutineName," & routine, "r.RunName," & jobnum, "rt.RoutineName," & routine)
    Else
        query = Split(fso.OpenTextFile(DataSources.QUERIES_PATH & "ML_ObsTraceability.sql").ReadAll, ";")(0)
        params = Array("r.RunName," & jobnum, "rt.RoutineName," & routine, "r.RunName," & jobnum, "rt.RoutineName," & routine, "r.RunName," & jobnum, "rt.RoutineName," & routine)
    End If
    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.ML7)

    GetFeatureTraceabilityData = sqlRecordSet.GetRows()
    Exit Function
    
FeatureTraceabilityErr:
    If Err.Number = vbObjectError + 2000 Then
        Dim emptyArr() As Variant
        GetFeatureTraceabilityData = emptyArr
        Exit Function
    Else
        Err.Raise Number:=Err.Number, Description:="Func: ML7-GetFeatureTraceabilityData" & vbCrLf & Err.Description
    End If
End Function

    'Date, Employee ID - Dont Filter out failed observations
Function GetAllFeatureTraceabilityData(jobnum As String, routine As String) As Variant()
    On Error GoTo AllFeatureTraceabilityErr
    Set fso = New FileSystemObject
    query = Split(fso.OpenTextFile(DataSources.QUERIES_PATH & "ML_ObsTraceability.sql").ReadAll, ";")(1)
    params = Array("r.RunName," & jobnum, "rt.RoutineName," & routine, "r.RunName," & jobnum, "rt.RoutineName," & routine, "r.RunName," & jobnum, "rt.RoutineName," & routine)
    
    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.ML7)

    GetAllFeatureTraceabilityData = sqlRecordSet.GetRows()
    Exit Function
    
AllFeatureTraceabilityErr:
    If Err.Number = vbObjectError + 2000 Then
        Dim emptyArr() As Variant
        GetAllFeatureTraceabilityData = emptyArr
        Exit Function
    Else
        Err.Raise Number:=Err.Number, Description:="Func: ML7-GetAllFeatureTraceabilityData" & vbCrLf & Err.Description
    End If
End Function

'Final Attribute Data Collection
'TODO: test if this would throw an erorr if the routine was never created yet
Function GetFinalAttrHeaders(jobnum As String, routine As String) As Variant()
    On Error GoTo GetFinalAttrHeadersErr
    Set fso = New FileSystemObject
    query = fso.OpenTextFile(DataSources.QUERIES_PATH & "Final_Attr_Headers.sql").ReadAll
    params = Array("r.RunName," & jobnum, "rt.RoutineName," & routine)
    
    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.ML7)

    GetFinalAttrHeaders = sqlRecordSet.GetRows()
    Exit Function
    
GetFinalAttrHeadersErr:
    If Err.Number = vbObjectError + 2000 Then
        Dim emptyArr() As Variant
        GetFinalAttrHeaders = emptyArr
        Exit Function
    Else
        Err.Raise Number:=Err.Number, Description:="Func: ML7-GetFinalAttrHeaders" & vbCrLf & Err.Description
    End If
End Function

Function GetFinalAttrResults(jobnum As String, routine As String) As Variant()
    On Error GoTo GetFinalAttrResultsErr
    Set fso = New FileSystemObject
    query = fso.OpenTextFile(DataSources.QUERIES_PATH & "Final_Attr_Results.sql").ReadAll
    params = Array("r.RunName," & jobnum, "rt.RoutineName," & routine)
    
    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.ML7)

    GetFinalAttrResults = sqlRecordSet.GetRows()
    Exit Function
    
GetFinalAttrResultsErr:
    If Err.Number = vbObjectError + 2000 Then
        Dim emptyArr() As Variant
        GetFinalAttrResults = emptyArr
        Exit Function
    Else
        Err.Raise Number:=Err.Number, Description:="Func: ML7-GetFinalAttrResults" & vbCrLf & Err.Description
    End If
End Function

Function GetFinalAttrTraceability(jobnum As String, routine As String) As Variant()
    On Error GoTo GetFinalAttrTraceabilityErr
    Set fso = New FileSystemObject
    query = fso.OpenTextFile(DataSources.QUERIES_PATH & "Final_Attr_Traceability.sql").ReadAll
    params = Array("r.RunName," & jobnum, "rt.RoutineName," & routine)
    
    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.ML7)

    GetFinalAttrTraceability = sqlRecordSet.GetRows()
    Exit Function
    
GetFinalAttrTraceabilityErr:
    If Err.Number = vbObjectError + 2000 Then
        Dim emptyArr() As Variant
        GetFinalAttrTraceability = emptyArr
        Exit Function
    Else
        Err.Raise Number:=Err.Number, Description:="Func: ML7-GetFinalAttrTraceability" & vbCrLf & Err.Description
    End If
End Function



    'Called by userform to determine how many Inspections it should require for FI_DIM
Function IsAllAttribrute(routine As Variant) As Boolean
    On Error GoTo AllAttribruteErr
    Set fso = New FileSystemObject
    query = fso.OpenTextFile(DataSources.QUERIES_PATH & "AnyVariables.sql").ReadAll
    params = Array("r.RoutineName," & routine)

    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.ML7)
    
AllAttribruteErr:
    'if errored because recordset.EOF, thats fine, it means it is all attribute features
    If Err.Number = vbObjectError + 2000 Then
        IsAllAttribrute = True
        Exit Function
    'otherwise it didn't error and we aren't at the end of the recordset
    ElseIf Not (sqlRecordSet.EOF) Then
        IsAllAttribrute = False
        Exit Function
    Else
        Err.Raise Number:=Err.Number, Description:="Func: ML7-IsAllAttribrute" & vbCrLf & Err.Description
    End If

End Function

    'All of the routines set up for this Part Number
Function GetPartRoutineList(partNum As String, Revision As String) As Variant()
    On Error GoTo PartRoutineListErr
    Set fso = New FileSystemObject
    Dim mlPartNum As String
    mlPartNum = partNum & "_" & Revision
    query = fso.OpenTextFile(DataSources.QUERIES_PATH & "PartRoutineList.sql").ReadAll
    params = Array("p.PartName," & mlPartNum)

    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.ML7)
    
    GetPartRoutineList = sqlRecordSet.GetRows()
    Exit Function
    
PartRoutineListErr:
    If Err.Number = vbObjectError + 2000 Then
        Err.Raise Number:=vbObjectError + 2000, Description:="No Routines Found for this Part Number" & vbCrLf & "This may not be a MeasurLink applicable part" & vbCrLf & Err.Description
    Else
        Err.Raise Number:=Err.Number, Description:="Func: ML7-GetPartRoutineList" & vbCrLf & Err.Description
    End If
    
End Function

    'All the routines created for this run
Function GetRunRoutineList(jobnum As String) As Variant()
    On Error GoTo RunRoutineListErr
    Set fso = New FileSystemObject
    query = fso.OpenTextFile(DataSources.QUERIES_PATH & "RunRoutineList.sql").ReadAll
    params = Array("r.RunName," & jobnum)

    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.ML7)
    
    GetRunRoutineList = sqlRecordSet.GetRows()
    Exit Function
    
RunRoutineListErr:
    If Err.Number = vbObjectError + 2000 Then
        Dim noRoutines() As Variant
        GetRunRoutineList = noRoutines
        Exit Function
    Else
        Err.Raise Number:=Err.Number, Description:="Func: ML7-GetRunRoutineList" & vbCrLf & Err.Description
    End If
    
End Function









''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'               InspectionKiosk
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

    'Customer name field in Epicor is often wrong, we need to translate it
Function GetCustomerName(jobnum As String) As String

    Dim searchParam As String
    Dim jobInfo() As Variant

    'If our job is an inventory job like 'NVxxx' then, we can just search by the first two characters
    If Len(jobnum) > 2 And Not IsNumeric(Left(jobnum, 1)) And Not IsNumeric(Mid(jobnum, 2, 1)) Then
        If Left(jobnum, 2) = "ME" Or Left(jobnum, 2) = "QA" Or (Left(jobnum, 1) = "R" And Not IsNumeric(Mid(jobnum, 3, 1))) Then
            GoTo 10
        Else
            searchParam = Left(jobnum, 2)
            GoTo 20
        End If
        
    End If
    
10
    'Otherwise use the incorrect "customer" name they put in the project database
    jobInfo = GetJobInformation(JobID:=jobnum)
    searchParam = jobInfo(4, 0)
20
    On Error GoTo CustomerNameErr
    Set fso = New FileSystemObject
    query = "SELECT CustomerName FROM InspectionKiosk.dbo.CustomerTranslation WHERE Abbreviation=?"
    params = Array("Abbreviation," & searchParam)

    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.Kiosk)


    GetCustomerName = sqlRecordSet.Fields(0).Value
    Exit Function
    
CustomerNameErr:
    Err.Raise Number:=Err.Number, Description:="Func: IK-GetCustomerName" & vbCrLf & Err.Description
End Function

    'Can't use static emails since positions often change, update the emails in the database accordingly.
Function GetCellLeadEmail(cell As Variant) As String
    On Error GoTo GetEmailErr
    Set fso = New FileSystemObject
    query = "SELECT Email FROM InspectionKiosk.dbo.VettingEmails WHERE Cell=?"
    params = Array("Cell," & cell)

    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.Kiosk)

    If Not sqlRecordSet.EOF Then
        GetCellLeadEmail = sqlRecordSet.Fields(0).Value
        Exit Function
    End If

GetEmailErr:
    Err.Raise Number:=Err.Number, Description:="Func: IK-GetCellLeadEmail" & vbCrLf & Err.Description
End Function


Function GetFlaggedShortRunIR(drawNum As String, rev As String, datePrinted As String) As Variant()
    On Error GoTo GetFlaggedShortRunIRErr
    Set fso = New FileSystemObject
    query = fso.OpenTextFile(DataSources.QUERIES_PATH & "IK_GetShortRunFlagged.sql").ReadAll()
    params = Array("datePrinted," & datePrinted, "vru.DrawNum," & drawNum, "vru.Revision," & rev)

    Call ExecQuery(query:=query, params:=params, conn_enum:=Connections.Kiosk)

    If Not sqlRecordSet.EOF Then
        GetFlaggedShortRunIR = sqlRecordSet.GetRows()
        Exit Function
    End If

GetFlaggedShortRunIRErr:
    'if errored because recordset.EOF, thats fine, it means that the part has never been flagged for short run inspection
    If Err.Number = vbObjectError + 2000 Then
        Dim noResults() As Variant
        GetFlaggedShortRunIR = noResults
        Exit Function
    Else
        Err.Raise Number:=Err.Number, Description:="Func: IK-GetFlaggedShortRunIR" & vbCrLf & Err.Description
    End If

End Function





