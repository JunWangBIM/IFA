# This software was developed at the National Institute of Standards and Technology by employees of 
# the Federal Government in the course of their official duties.  Pursuant to Title 17 Section 105 
# of the United States Code this software is not subject to copyright protection and is in the 
# public domain. This software is an experimental system.  NIST assumes no responsibility whatsoever 
# for its use by other parties, and makes no guarantees, expressed or implied, about its quality, 
# reliability, or any other characteristic.  We would appreciate acknowledgement if the software is 
# used.
# 
# This software can be redistributed and/or modified freely provided that any derivative works bear 
# some notice that they are derived from it, and any modified versions bear some notice that they 
# have been modified. 

global env

set scriptName [info script]
set wdir [file dirname [info script]]
set auto_path [linsert $auto_path 0 $wdir]

puts "\n--------------------------------------------------------------------------------"
puts "NIST IFC File Analyzer (v[getVersion])"

if {[catch {
  package require Tclx
  package require tcom
  package require twapi
} emsg]} {
  set dir $wdir
  set c1 [string first [file tail [info nameofexecutable]] $dir]
  if {$c1 != -1} {set dir [string range $dir 0 $c1-1]}
  puts "\nERROR: $emsg\n\nThere might be a problem running this program from a directory with accented, non-English, or symbol characters in the pathname.\n\n[file nativename $dir]\n\nRun the software from a directory without any special characters in the pathname.\n\nPlease contact Robert Lipman (robert.lipman@nist.gov) for other problems."
  exit
}

foreach id {XL_OPEN XL_LINK1 XL_FPREC EX_A2P3D EX_LP EX_ANAL COUNT INVERSE SORT \
            PR_BEAM PR_PROF PR_PROP PR_GUID PR_HVAC PR_UNIT PR_COMM PR_RELA \
            PR_ELEC PR_QUAN PR_REPR PR_SRVC PR_ANAL PR_PRES PR_MTRL PR_GEOM PR_USER} {set opt($id) 1}

set opt(PR_GUID) 0
set opt(PR_GEOM) 0
set opt(PR_USER) 0

set opt(EX_LP)    0
set opt(EX_A2P3D) 0
set opt(EX_ANAL)  0

set opt(XL_FPREC) 0
set opt(FN_APPEND) 0

set opt(DEBUGINV) 0

set opt(XLSCSV) Excel

# -----------------------------------------------------------------------------------------------------
# IFC pecific data
setData_IFC

# -----------------------------------------------------------------------------------------------------
# set drive, myhome, mydocs, mydesk
setHomeDir

set userWriteDir $mydocs
set writeDir ""
set writeDirType 0
set maxfiles 1000
set row_limit 1003

set openFileList {}
set fileDir  $mydocs
set fileDir1 $mydocs
set optionsFile1 [file nativename [file join $fileDir .ifc_excel.dat]]
set optionsFile2 [file nativename [file join $fileDir ITE_options.dat]]
set optionsFile3 [file nativename [file join $fileDir IFC_Excel_options.dat]]
set optionsFile4 [file nativename [file join $fileDir IFC-File-Analyzer-options.dat]]

if {(![file exists $optionsFile1] && ![file exists $optionsFile2] && ![file exists $optionsFile3] && ![file exists $optionsFile4]) || \
     [file exists $optionsFile4]} {
  set optionsFile $optionsFile4
} else {
  catch {
    if {[file exists $optionsFile1]} {
      file copy -force $optionsFile1 $optionsFile4
      file delete -force $optionsFile1
      set optionsFile $optionsFile4
    } elseif {[file exists $optionsFile2]} {
      file copy -force $optionsFile2 $optionsFile4
      file delete -force $optionsFile2
      set optionsFile $optionsFile4
    } elseif {[file exists $optionsFile3]} {
      file copy -force $optionsFile3 $optionsFile4
      file delete -force $optionsFile3
      set optionsFile $optionsFile4
    }
  } optionserr
}

set filemenuinc 4
set lenlist 25
set upgrade 0
set upgradeIFCsvr 0
set yrexcel ""

set writeDir $userWriteDir

set userXLSFile ""

set dispCmd ""
set dispCmds {}

# set program files, environment variables will be in the correct language
set pf32 "C:\\Program Files (x86)"
if {[info exists env(ProgramFiles)]} {set pf32 $env(ProgramFiles)}
set pf64 ""
if {[info exists env(ProgramW6432)]} {set pf64 $env(ProgramW6432)}
set ifcsvrdir [file join $pf32 IFCsvrR300 dll]

set firsttime 1
set lastXLS  ""
set lastXLS1 ""
set verite 0

# check for options file and source
set optionserr ""
if {[file exists $optionsFile]} {
  catch {source $optionsFile} optionserr
  if {[string first "+" $optionserr] == 0} {set optionserr ""}
  catch {unset opt(PR_TYPE)}
  catch {unset opt(XL_XLSX)}
}
if {[info exists userEntityFile]} {
  if {![file exists $userEntityFile]} {
    set userEntityFile ""
    set opt(PR_USER) 0
  }
}

#-------------------------------------------------------------------------------
# check for IFCsvr
if {![file exists [file join $pf32 IFCsvrR300 dll IFCsvrR300.dll]]} {
  outputMsg " "
  errorMsg "IFCsvr needs to be installed for the IFC File Analyzer to read IFC files."
  outputMsg "\nInstall IFCsvr -------------------------------------------------------------" blue
  outputMsg " 1 - Run the GUI version of the IFC File Analyzer (IFC-File-Analyzer.exe)"
  outputMsg " 2 - Follow the instructions to install IFCsvr"
  outputMsg " 3 - Rerun this software"
} 

# no arguments, no file, print help, and exit

if {$argc == 1} {set arg [string tolower [lindex $argv 0]]}
if {$argc == 0 || ($argc == 1 && ($arg == "help" || $arg == "-help" || $arg == "-h" || $arg == "-v"))} {
  puts "\nUsage: IFC-File-Analyzer-CL.exe myfile.ifc \[csv\] \[noopen\]

Optional command line settings:
  csv     Generate CSV files
  noopen  Do not open the Spreadhseet after it has been generated

 Options last used in the GUI version are used in this program.

 If 'myfile.ifc' has spaces, put quotes around the file name
   \"C:/mydir/my file.ifc\"
 
 Existing Spreadsheets are always overwritten.

 When the IFC file is opened, errors and warnings might appear in the output between
 the 'Begin ST-Developer output' and 'End ST-Developer output' messages.  Use the
 'stats' option to only check for the errors and warnings without generating a
 spreadsheet.
  
Disclaimers
 This software was developed at the National Institute of Standards and Technology by
 employees of the Federal Government in the course of their official duties.  Pursuant
 to Title 17 Section 105 of the United States Code this software is not subject to
 copyright protection and is in the public domain.  This software is an experimental
 system.  NIST assumes no responsibility whatsoever for its use by other parties, and
 makes no guarantees, expressed or implied, about its quality, reliability, or any
 other characteristic.  NIST Disclaimer: https://www.nist.gov/disclaimer

Credits
- Generating spreadsheets:       Microsoft Excel (https://products.office.com/excel)
- Reading and parsing IFC files: IFCsvr (https://groups.yahoo.com/neo/groups/ifcsvr-users/info)
                                 License agreement C:\\Program Files (x86)\\IFCsvrR300\\doc
                                 IFCsvr ActiveX Component, Copyright \u00A9 1999, 2005 SECOM Co., Ltd. All Rights Reserved"

  exit
}

# get arguments and initialize variables
for {set i 1} {$i <= 100} {incr i} {
  set arg [string tolower [lindex $argv $i]]
  if {$arg != ""} {
    lappend larg $arg
    if {[string first "noopen" $arg] == 0} {set opt(XL_OPEN) 0}                              
    if {[string first "csv"    $arg] == 0} {set opt(XLSCSV) "CSV"}                              
  }
}

# options used from GUI version
#puts "\nOptions last used in the GUI version are being used.  Some of them are:"
#if {$opt(COUNT)}    {puts " Count Duplicates"}
#if {$opt(SORT)}     {puts " Generate Tables"}
#if {$opt(INVERSE)}  {puts " Inverse Relationships"}
#if {$opt(EX_LP)}    {puts " Expand IfcLocalPlacement"}
#if {$opt(EX_A2P3D)} {puts " Expand IfcAxis2Placement"}

# IFC file name
set localName [lindex $argv 0]
if {[string first ":" $localName] == -1} {set localName [file join [pwd] $localName]}
set localName [file nativename $localName]
set remoteName $localName
set fext [string tolower [file extension $localName]]

if {[file exists $localName]} {
  genExcel
} else {
  outputMsg "File does not exist: [truncFileName $localName]"
}