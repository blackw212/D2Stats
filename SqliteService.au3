#include <SQLite.au3>
#include <SQLite.dll.au3>
;#include <MsgBoxConstants.au3>

; Initialize SQLite
;If _SQLite_Startup() <> $SQLITE_OK Then
;    MsgBox(16, "SQLite Error", "Failed to initialize SQLite.")
;    Exit
;EndIf

; Global SQLite connection handle
Global $g_hDB

; Function to initialize the database and create tables if not exists
Func InitializeDatabase($sDBPath)
    If Not FileExists($sDBPath) Then
        MsgBox(16, "SQLite Error", "Database could not be located. Path i looked for: " & $sDBPath)
        Exit
    EndIf

    local $init = _SQLite_Startup(@ScriptDir & "\sqlite3" & (@AutoItX64 ? "_x64" : "") & ".dll", False, 1) ; force locally?
    If @error Then
        MsgBox(16, "SQLite Error", "Failed to initialize SQLite. Error: " & _SQLite_ErrMsg())
        Exit
    EndIf

    ; Open the SQLite database
    $g_hDB = _SQLite_Open($sDBPath)
    If @error Then
        MsgBox(16, "SQLite Error", "Failed to open SQLite database. Error: " & _SQLite_ErrMsg())
        Exit
    EndIf

    ; Create tables
    If _SQLite_Exec($g_hDB, "CREATE TABLE IF NOT EXISTS ItemStash (ID INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT, Location TEXT, Character TEXT);") <> $SQLITE_OK Then
        MsgBox(16, "SQLite Error", "Failed to create ItemStash: " & _SQLite_ErrMsg())
    EndIf

    If _SQLite_Exec($g_hDB, "CREATE TABLE IF NOT EXISTS ItemDrops (ID INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT, Location TEXT, Character TEXT, Date TEXT);") <> $SQLITE_OK Then
        MsgBox(16, "SQLite Error", "Failed to create ItemDrops: " & _SQLite_ErrMsg())
    EndIf

    If _SQLite_Exec($g_hDB, "CREATE TABLE IF NOT EXISTS ItemCustomLists (ID INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT, ItemName TEXT);") <> $SQLITE_OK Then
        MsgBox(16, "SQLite Error", "Failed to create ItemCustomLists: " & _SQLite_ErrMsg())
    EndIf
EndFunc

; Function to insert a new entry into ItemDrops
Func AddItemDrop($sName, $sLocation, $sCharacter, $sDate)
    ; Prepare the SQL statement
    Local $sSQL = "INSERT INTO ItemDrops (Name, Location, Character, Date) VALUES ('" & _
                    StringReplace($sName, "'", "''") & "', '" & _
                    StringReplace($sLocation, "'", "''") & "', '" & _
                    StringReplace($sCharacter, "'", "''") & "', '" & _
                    StringReplace($sDate, "'", "''") & "');"

    ; Execute the query
    If _SQLite_Exec($g_hDB, $sSQL) <> $SQLITE_OK Then
        MsgBox(16, "SQLite Error", "Failed to add item drop: " & _SQLite_ErrMsg())
        Return False
    EndIf

    Return True
EndFunc

; Function to add or remove items from ItemCustomLists
Func ModifyItemCustomList($sName, $sItemName, $bAdd = True)
    If $bAdd Then
        ; Prepare the SQL statement for adding
        Local $sSQL = "INSERT INTO ItemCustomLists (Name, ItemName) VALUES ('" & _
                       StringReplace($sName, "'", "''") & "', '" & _
                       StringReplace($sItemName, "'", "''") & "');"
    Else
        ; Prepare the SQL statement for removing
        Local $sSQL = "DELETE FROM ItemCustomLists WHERE Name = '" & _
                       StringReplace($sName, "'", "''") & "' AND ItemName = '" & _
                       StringReplace($sItemName, "'", "''") & "';"
    EndIf

    ; Execute the query
    If _SQLite_Exec($g_hDB, $sSQL) <> $SQLITE_OK Then
        MsgBox(16, "SQLite Error", "Failed to modify custom list: " & _SQLite_ErrMsg())
        Return False
    EndIf

    Return True
EndFunc

; Function to add or remove items from ItemCustomLists
Func GetItemsByCustomListName($sName)
    ; Prepare the SQL statement for selecting
    Local $sSQL = "SELECT ItemName FROM ItemCustomLists WHERE Name = '" & StringReplace($sName, "'", "''") & "';"
    Local $hQuery
    Local $aRow
    Local $aResults[1] = [""] ; Initialize results array

    ; Execute the SQL query
    If _SQLite_Query($g_hDB, $sSQL, $hQuery) <> $SQLITE_OK Then
        MsgBox(16, "SQLite Error", "Failed to execute query: " & _SQLite_ErrMsg())
        Return $aResults
    EndIf

    ; Fetch data
    While _SQLite_FetchData($hQuery, $aRow) = $SQLITE_OK
        ReDim $aResults[UBound($aResults) + 1]
        $aResults[UBound($aResults) - 1] = $aRow[0] ; Add the "Name" to results
    WEnd

    _SQLite_QueryFinalize($hQuery) ; Finalize the query

    ; Remove the empty placeholder
    ReDim $aResults[UBound($aResults) - 1]

    Return $aResults
EndFunc

; Function to delete specific entry in ItemCustomLists
Func DeleteCustomListEntry($sName, $sItemName)
    Local $sSQL = "DELETE FROM ItemCustomLists WHERE Name = '" & StringReplace($sName, "'", "''") & _
                  "' AND ItemName = '" & StringReplace($sItemName, "'", "''") & "';"
    If _SQLite_Exec($g_hDB, $sSQL) <> $SQLITE_OK Then
        MsgBox(16, "SQLite Error", "Failed to delete item: " & _SQLite_ErrMsg())
        Return
    EndIf
EndFunc

; Function to delete all entries related to a Name in ItemCustomLists
Func DeleteCustomListByName($sName)
    Local $sSQL = "DELETE FROM ItemCustomLists WHERE Name = '" & StringReplace($sName, "'", "''") & "';"
    _SQLite_Exec($g_hDB, $sSQL)
EndFunc

; Function to get all unique custom lists by name
Func GetUniqueCustomLists()
    Local $sSQL = "SELECT DISTINCT Name FROM ItemCustomLists;"
    Local $hQuery
    Local $aRow
    Local $aResults[1] = [""] ; Initialize results array

    ; Execute the SQL query
    If _SQLite_Query($g_hDB, $sSQL, $hQuery) <> $SQLITE_OK Then
        MsgBox(16, "SQLite Error", "Failed to execute query: " & _SQLite_ErrMsg())
        Return $aResults
    EndIf

    ; Fetch data
    While _SQLite_FetchData($hQuery, $aRow) = $SQLITE_OK
        ReDim $aResults[UBound($aResults) + 1]
        $aResults[UBound($aResults) - 1] = $aRow[0] ; Add the "Name" to results
    WEnd

    _SQLite_QueryFinalize($hQuery) ; Finalize the query

    ; Remove the empty placeholder
    ReDim $aResults[UBound($aResults) - 1]

    Return $aResults
EndFunc

; Function to search for items in ItemStash by name
Func SearchItemStashByName($sName)
    Local $sSQL = "SELECT Name, Location, Character FROM ItemStash WHERE Name LIKE '" & StringReplace($sName, "'", "''") & "';"
    Local $hQuery, $aResults[1][3] = [[0, ""]]

    ; Prepare and execute the query
    If _SQLite_Query($g_hDB, $sSQL, $hQuery) <> $SQLITE_OK Then
        MsgBox(16, "SQLite Error", "Failed to execute query SearchItemStashByName: " & _SQLite_ErrMsg())
        Return $aResults
    EndIf

    ; Fetch results
    Local $iIndex = 0, $aRow
    While _SQLite_FetchData($hQuery, $aRow) = $SQLITE_OK
        $iIndex += 1
        ReDim $aResults[$iIndex + 1][3]
        $aResults[$iIndex][0] = $aRow[0] ; Name
        $aResults[$iIndex][1] = $aRow[1] ; Location
        $aResults[$iIndex][2] = $aRow[2] ; Character
        $aResults[0][0] = $iIndex
    WEnd
    _SQLite_QueryFinalize($hQuery)

    Return $aResults
EndFunc

; Function to close the database connection
Func CloseDatabase()
    If $g_hDB <> 0 Then _SQLite_Close($g_hDB)
    _SQLite_Shutdown()
EndFunc

; Example Usage
; Initialize the database
;InitializeDatabase("example.db")

; Add entries to ItemDrops
;AddItemDrop("Sword of Valor", "Dungeon", "HeroX", "2024-11-17")

; Add an item to ItemCustomLists
;ModifyItemCustomList("Favorite Items", "Sword of Valor", True)

; Delete all entries for a custom list name
;DeleteCustomListByName("Favorite Items")

; Search for items in ItemStash
;Local $aSearchResults = SearchItemStashByName("Sword")
;_ArrayDisplay($aSearchResults) ; Assuming _ArrayDisplay is available for debugging

; Close the database
;CloseDatabase()