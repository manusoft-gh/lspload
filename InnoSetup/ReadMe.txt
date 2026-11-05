 Inno Setup Lisp Plugin Installer Script 2.1           2026-11-05
 
Setup script demonstrating how to install a lisp plugin on any or all
supported versions of AutoCAD, Bricscad, or ZWCAD+.


LEGAL NOTICE

Copyright 2026 ManuSoft (http://www.manusoft.com)
All Rights Reserved

The setup script and related sample files may be freely modified and used
for any purpose. The script and related sample files may be redistributed
if any revisions are clearly documented and this legal notice accompanies
all files.

ManuSoft disclaims any and all liability for your use of this software.
The software is provided "as is" without warranty of any kind, either
express or implied.


PREREQUISITES

The Inno Setup Compiler is required to build this script. The easiest
(and recommended) way to run the compiler is by using Inno Script Studio.
Inno Script Studio is a standalone IDE that is included in the
Unicode Inno Setup QuickStart Pack available at the Inno Setup Downloads
page:
http://www.jrsoftware.org/isdl.php

The generated\ folder must sit beside MyLispPlugin.iss. The compiler
includes generated\HostsFiles.iss and generated\HostsCode.iss; compiling
the script without that folder will fail.

This script uses LspLoad to load a lisp plugin via registry based
demand-load keys. The LspLoad binaries must be obtained separately and
placed in a LspLoad subfolder relative to the folder containing this
script. The LspLoad binaries may be obtained from the ManuSoft web site
by downloading LspLoad.zip from the ARX freebies page:
http://www.manusoft.com/software/freebies/arx.html


USAGE

The script is intended to demonstrate how to create a setup program for
installing (and uninstalling) a lisp plugin for any supported host
application. The default configuration builds a setup program that
installs and configures a ficticious plugin named MyLispPlugin. The
MyLispPlugin defines two commands: MyCommand1 and MyCommand2. After
installing the plugin, the commands are ready to use when any supported
host application is started.

The sample script is designed to be used as a template, so that with a
few changes where indicated, it can be quickly adapted to build a setup
program for a real lisp plugin.

The steps for building the sample script are very simple. The script,
the generated\ fragments, and associated files should be in the same
folder, and the LspLoad binaries should be placed in a subfolder named
LspLoad. If Inno Script Studio is installed, simply double click on the
MyLispPlugin.iss file to open it in the IDE. Choose Compile in the
Project menu to build the setup file MyLispPluginSetup.exe, which will
be created in the Output subfolder.

Run the setup program to install the sample plugin. If the setup
completes, you should be able to use the sample commands MyCommand1
and MyCommand2 in any supported host application. The script adds a
shortcut in the Start menu under MyCompany\MyLispPlugin to uninstall
the sample plugin. Uninstalling the sample should remove all files
and registry entries that were created during installation. Note that
uninstall will NOT remove changes made at runtime, such as additions
to TRUSTEDPATHS in AutoCAD 2014 and later.


NOTES

The sample script does not perform any common plugin initialization
functions like loading a partial menu, however it does demonstrate
how to add the plugin folder to the TRUSTEDPATHS in AutoCAD 2014 and
later versions.

Complete source code for the LspLoad binaries is available at the
ManuSoft web site:
http://www.manusoft.com/resources/arxtips/demandloadvlx.html

If you are interested in utilizing a third party software copy
protection library that cannot be used directly from lisp, it is
usually possible to implement and expose a lisp callable interface
directly inside the LspLoad modules. If you need assistance, please
contact ManuSoft to discuss a custom solution:
http://www.manusoft.com/home/about.html


SUPPORT

The best source of support is the community of programmers on the
various CAD programming web sites and the community of Inno Setup
users at the various Inno Setup discussion forums.


DONATE

This project represents a substantial amount of time and resources
that has been provided for you to use free of charge. If you would
like to support the project financially, you may either contribute
via PayPal directly to paypal@manusoft.com or help grow the wider
community of lisp plugin developers by contributing to the open
source OpenDCL project:
http://opendcl.com/wordpress/?page_id=190
