<# DMICPCH ************************************************}
{ DMICP Based Code Header                                  }
{ Unit Name : ConvertFilesToANSI.ps1                       }
{ File Ref  : AD1905241400                                 }
{ Added By  : Antony Danby                                 }
{ -------------------------------------------------------- }
{ Development History                                      }
{- Date           : AD1905241400                           }
{- File Version   : FOC.DMICP001.0001                      }
{- Doc / Bug Ref  : WI                  }
{- Developer      : Antony Danby                           }
{ Comments                                                 }
{ Powershell script to remove characters <> x00 - x7f      }
{ In others words anything above 256 or below 00           }
{                                                          }
{******************************************************** #>

Get-ChildItem ".\Scripts" -Filter *.sql | 
Foreach-Object {
    $contents = Get-Content $_.FullName 
    # Use regex to replace all the ASCII chrs outside of 00 to 7F with ""
    $contents = $contents -replace '[^\x00-\x7F]+',""
    # Now remove and recreate the file
    Remove-Item $_.FullName
    $script = New-Item -ItemType file $_.FullName
    Add-Content $script -Value $contents -Encoding ASCII
}