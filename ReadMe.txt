LspLoad 6.10                              2026-10-20

 ManuSoft (http://www.manusoft.com)


  ** Legal Stuff **

LspLoad is placed in the public domain. The LspLoad source 
code and binaries may be freely modified, redistributed, or 
used for any purpose without attribution.


  ** What it is **

LspLoad is designed to utilize AutoCAD, Bricscad, and ZWCAD 
registry based demand load features to automatically load 
an application's lisp file when the host program starts.


  ** What it does **

It's up to the application developer to setup the registry 
keys that load the LspLoad ARX/BRX/ZRX module. When the 
LspLoad module loads, it attempts to load an associated 
lisp file from the same folder. It does this by sending a 
lisp expression to the command line in this form (where 
<filename> is determined by the LspLoad module's filename 
up to the first period character):
(vl-load-all "<filename>")

Since no file extension is specified in the call to 
(vl-load-all), the function will be able to load any 
of either .lsp, .vlx, or .fas files with the given name.

In addition to loading the assocated lisp file, LspLoad 
defines a lisp function that returns the folder where 
it was loaded from. This function should be used by the 
lisp application to find support files that are installed in 
the same folder (or in a subfolder). The name of the 
function is (GetPathOfXXXXX) where XXXXX is the base 
filename of the LspLoad module.

Developers should rename the LspLoad ARX/BRX/ZRX module 
so that its base filename matches their lisp file.


  ** Support **

ManuSoft does not offer any technical support for this
software, however if you find any other problems please 
contact us with information about the problem and how to 
reproduce it.


 *****************************************
 ****  ManuSoft                       ****
 ****  10505 Deerberry Dr.            ****
 ****  Land O Lakes, FL, USA 34638    ****
 ****  +1 813-643-1227 (Voice)        ****
 ****  http://www.manusoft.com        ****
 ****  support@manusoft.com           ****
 *****************************************
