<# DMICPCH ************************************************}
{ DMICP Based Code Header                                  }
{ Unit Name : ScriptPCSDatabases.ps1                       }
{ File Ref  : AD1905131400                                 }
{ Added By  : Fred Blogs                                   }
{ -------------------------------------------------------- }
{ Development History                                      }
{- Date           : 1905131400                             }
{- File Version   : FOC.DMICP001.0001                      }
{- Doc / Bug Ref  : WI903846                               }
{- Developer      : Antony Danby                           }
{ Comments                                                 }
{ Powershell script to script out all PCS databases.       }
{                                                          }
{******************************************************** #>

$date_ = (Get-Date -f yyyyMMdd)

# If you have a named instance, you should put the name; 
# otherwise leave as (local)
$ServerName = "(local)" 

# Build up the base path where the scripts will be written to
$path = "c:\backup\objects\"+"$date_"

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
$serverInstance = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName

$time_ = (Get-Date -f T)
Clear-Host
Write-Host("$time_" +", Starting")

# The objects to backup
$IncludeTypes = @(  "Logins",
                    "Users",
                    "Roles",
                    "Schemas",
                    "UserDefinedTypes",
                    "UserDefinedDataTypes",
                    "UserDefinedTableTypes",
                    "UserDefinedFunctions",
                    "Tables",
                    "Views",
                    "StoredProcedures" )                   

# We can add to this if we need to
$LoginList = @("sa","ClinicalUser")

# The objects to exclude
$ExcludeSchemas = @("sys","Information_Schema")

# Setup the scripting options
$so = new-object ('Microsoft.SqlServer.Management.Smo.ScriptingOptions')
$so.AllowSystemObjects = $true
$so.AnsiFile = $true 
$so.AnsiPadding = $true
$so.Bindings = $true 
$so.ContinueScriptingOnError = $false
$so.ConvertUserDefinedDataTypesToBaseType = $false

# Setup all the DRI scripting options
$so.DRIAll= $true
$so.DriAllConstraints = $true
$so.DriAllKeys = $true
$so.DriChecks = $true
$so.DriForeignKeys = $true
$so.DriIndexes = $true
$so.DriIncludeSystemNames = $true 
$so.DriNonClustered = $true
$so.DriUniqueKeys = $true
$so.DriWithNoCheck = $true
$so.DriPrimaryKey = $true 

$so.ExtendedProperties= $true
$so.FullTextIndexes = $true
$so.IncludeDatabaseRoleMemberships = $true 
$so.IncludeHeaders = $false; 
$so.IncludeIfNotExists = $true 
$so.Indexes= $true
$so.Permissions = $true
$so.Triggers= $true
$so.LoginSid = $true
$so.ScriptDrops = $false
$so.SchemaQualifyForeignKeysReferences = $true
$so.ToFileOnly = $false
$so.Filename = ""

# Script the logins; Only needs to be scripted once
# The resultant script is placed in the root of the
# folder we are writing too
$logins = $serverInstance.Logins

if ( !(Test-Path $path))
    {$null=new-item -type directory -name "$date_"-path "c:\backup\objects\"}

$loginscript = "$path"+"\"+"Logins.sql"
$script = New-Item -ItemType file "$loginscript"
foreach ($login in $LoginList) 
{
    $loginsql = $logins[$login].Script()
    Write-Host("  > Login : $login")
    Add-Content $script $loginsql
}

$so.LoginSid = $false

# The list of the databases we wish to script
# Any other database will not be scripted
$PCSDatabases = @(  "EMIS0001",
                    "EMISMESSAGING",
                    "EMISPATIENT",
                    "EMISSYSTEM",
                    "SUPPORT"  )

# This is the database collection
# If we need to we can filter our databases here
$dbs = $serverInstance.Databases 

foreach ($db in $dbs)
{    
    # We only want PCS databases, so we need to exclude
    # anything that is not in that list
    if ($PCSDatabases -contains $db.Name)
    {
        $time_ = (Get-Date -f T)
        Write-Host("$time_" +", Scripting : $db")

        $dbname = "$db".replace("[","").replace("]","")
        $dbpath = "$path"+ "\"+"$dbname" + "\"
        $dbscript = "$dbpath"+"\"+"$dbname"+".sql"
        $dbcreationscript = "$dbpath"+"\_"+"$dbname"+"_Creation.sql"
    
        if ( !(Test-Path $dbpath))
            {$null=new-item -type directory -name "$dbname"-path "$path"}
    
        # Script out the database creation and settings
        $so.ToFileOnly = $true
        $so.Filename = "$dbcreationscript"
        $so.ScriptBatchTerminator = $true
        $db.Script($so) 

        # Reset the script options
        $so.ScriptBatchTerminator = $false
        $so.ToFileOnly = $false
        $so.Filename = ""
    
        # Loop around all the database types 
        foreach ($Type in $IncludeTypes)
        {
            Write-Host("  > Type : $Type")
            $objpath = "$dbpath" + "$Type" + "\"
                                
            if ( !(Test-Path $objpath))
                {$null=new-item -type directory -name "$Type"-path "$dbpath"}

            foreach ($objs in $db.$Type)
            {
                if ($ExcludeSchemas -notcontains $objs.Schema )
                {
                    $ObjName = "$objs".replace("[","").replace("]","")
                    $OutFile = "$objpath" + "$ObjName" + ".sql" 
                    $sql     = $objs.Script($so)+"GO`r`n"                              

                    # Pipe the sql to the file for this individual object
                    $sql | out-File $OutFile
                    # Add this sql to the database script
                    Add-Content $dbscript $sql
                }
            }
        }
    
        # We now need to go and add the Login script, the creation script
        # and the database script together to form a full database script
        $time_ = (Get-Date -f T)
        Write-Host("$time_" +", Concatenating scripts : $db")
        
        $loginScriptContents = Get-Content "$loginscript"
        $dbScriptContents = Get-Content "$dbscript"
        $creationScriptContents = Get-Content "$dbcreationscript"
        if ($dbname -eq 'EMIS0001') {$dbname = "EMIS"}
        $fullscript = "$path"+"\BASELINE_"+"$dbname"+"_DATABASE_SCRIPT.sql"
        $script = New-Item -ItemType file "$fullscript"
        Add-Content $script $creationScriptContents
        Add-Content $script $loginScriptContents
        Add-Content $script $dbScriptContents

        $time_ = (Get-Date -f T)
        Write-Host("$time_" +", Database Completed : $db")
    }
}

$time_ = (Get-Date -f T)
Write-Host("$time_" +", Completed")