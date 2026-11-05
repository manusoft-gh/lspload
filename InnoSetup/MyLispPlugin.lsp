;; Inno Setup Lisp Plugin Installer Script
;; 
;; Main application lisp file that loads at startup. This file should define
;; the application's command autoloader stubs and perform any necessary
;; initialization, but it should be short and sweet so it doesn't cause
;; any delays at startup.

;; LEGAL NOTICE
;;
;; Copyright 2026 ManuSoft (http://www.manusoft.com)
;; All Rights Reserved
;;
;; The setup script and related sample files may be freely modified and used
;; for any purpose. The script and related sample files may be redistributed
;; if any revisions are clearly documented and this legal notice accompanies
;; all files.
;;
;; ManuSoft disclaims any and all liability for your use of this software.
;; The software is provided "as is" without warranty of any kind, either
;; express or implied.


;; Obtain application installation folder from registry
;; * Rename this function before distributing it with a real plugin!
(defun *MyLispPlugin-GetAppFolder ()
  (vl-string-right-trim "\\/"
    (cond ; Check all three possible registry locations
      ( (vl-registry-read "HKEY_CURRENT_USER\\Software\\MyCompany\\MyLispPlugin" "InstallPath")
      )
      ( (vl-registry-read "HKEY_LOCAL_MACHINE\\Software\\MyCompany\\MyLispPlugin" "InstallPath")
      )
      ( (vl-registry-read "HKEY_LOCAL_MACHINE\\Software\\Wow6432Node\\MyCompany\\MyLispPlugin" "InstallPath")
      )
      ( ""
      )
    )
  )
)


;; Define autoload command stubs
;; * "MyLispPluginCmds" is the lisp filename that implements the commands
(autoload (strcat (vl-string-translate "\\" "/" (*MyLispPlugin-GetAppFolder)) "/" "MyLispPluginCmds")
  '(
    "MyCommand1"
    "MyCommand2"
   )
)


;; In AutoCAD 2014+, add the app folder to TRUSTEDPATHS
;; * Note that this change will not be undone when the plugin is uninstalled
(
  (lambda (/ trustedpaths appfolder startpos endpos found)
    (if (and (/= (getvar "PROGRAM") "BRICSCAD") (setq trustedpaths (getvar "TRUSTEDPATHS")))
      (progn
        (setq appfolder (*MyLispPlugin-GetAppFolder))
        (while (and (not found) (setq endpos (vl-string-position (ascii ";") trustedpaths endpos)))
          (setq found
            (eq
              (strcase appfolder)
              (strcase
                (substr
                  trustedpaths
                  (if startpos startpos (setq startpos 1))
                  (- (setq endpos (1+ endpos)) startpos)
                )
              )
            )
          )
          (setq startpos (1+ endpos))
        )
        (if (not found) (setq found (eq appfolder (substr trustedpaths (if startpos startpos 1)))))
        (if (not found) (setvar "TRUSTEDPATHS" (strcat trustedpaths ";" appfolder)))
      )
    )
  )
)


;; NOTE: Please resist the urge to add your app folder to the support path. Your
;; app already knows where its files are at, so just specify a complete path and
;; leave the support path uncluttered. CAD managers will thank you.


(princ "\nMyLispPlugin loaded -- MYCOMMAND1 and MYCOMMAND2 are now available.\n")

(princ)

;;;-----BEGIN-SIGNATURE-----
;;; 5wUAADCCBeEGCSqGSIb3DQEHAqCCBdIwggXOAgEBMQ4wDAYIKoZIzj0EAwMFADAL
;;; BgkqhkiG9w0BBwGgggPAMIIDvDCCA0GgAwIBAgIQY41ujedUudgLItW1oB6uMTAK
;;; BggqhkjOPQQDAzB4MQswCQYDVQQGEwJVUzEOMAwGA1UECAwFVGV4YXMxEDAOBgNV
;;; BAcMB0hvdXN0b24xETAPBgNVBAoMCFNTTCBDb3JwMTQwMgYDVQQDDCtTU0wuY29t
;;; IENvZGUgU2lnbmluZyBJbnRlcm1lZGlhdGUgQ0EgRUNDIFIyMB4XDTI2MDcwNjE4
;;; NDAzM1oXDTI3MTAwNzE4NDAzM1owczELMAkGA1UEBhMCVVMxEDAOBgNVBAgMB0Zs
;;; b3JpZGExFjAUBgNVBAcMDUxhbmQgTycgTGFrZXMxETAPBgNVBAoMCE1BTlVTT0ZU
;;; MRQwEgYDVQQLDAtFbmdpbmVlcmluZzERMA8GA1UEAwwITUFOVVNPRlQwdjAQBgcq
;;; hkjOPQIBBgUrgQQAIgNiAAQZ5ODxAyLUuFHhL2bdROBWz+3Ha1J3AjxPD7sEGQgu
;;; 1bBIWMRiWXP9B2QKG/vAk3KvQZaOP32OoDSKihZriXdYbgXlt6FbMdPbxPUILmH7
;;; mp8/cJ0w8LC09T6sV6MLbmSjggGTMIIBjzAMBgNVHRMBAf8EAjAAMB8GA1UdIwQY
;;; MBaAFDJ4sQ6Q20bPGs+2YxFt/jDnZ1QwMHkGCCsGAQUFBwEBBG0wazBHBggrBgEF
;;; BQcwAoY7aHR0cDovL2NlcnQuc3NsLmNvbS9TU0xjb20tU3ViQ0EtY29kZVNpZ25p
;;; bmctRUNDLTM4NC1SMi5jZXIwIAYIKwYBBQUHMAGGFGh0dHA6Ly9vY3Nwcy5zc2wu
;;; Y29tMFEGA1UdIARKMEgwCAYGZ4EMAQQBMDwGDCsGAQQBgqkwAQMDATAsMCoGCCsG
;;; AQUFBwIBFh5odHRwczovL3d3dy5zc2wuY29tL3JlcG9zaXRvcnkwEwYDVR0lBAww
;;; CgYIKwYBBQUHAwMwTAYDVR0fBEUwQzBBoD+gPYY7aHR0cDovL2NybHMuc3NsLmNv
;;; bS9TU0xjb20tU3ViQ0EtY29kZVNpZ25pbmctRUNDLTM4NC1SMi5jcmwwHQYDVR0O
;;; BBYEFNHh1c+HWC/VnBp4XZMhy5YC4xaNMA4GA1UdDwEB/wQEAwIHgDAKBggqhkjO
;;; PQQDAwNpADBmAjEA34DOb5IC8XQzLF3kOM1S7qwsQn0dJQrtObv64Xf6v7fhj///
;;; SGPAqBMJUSyDiJR9AjEA+j21dj4t5AGd9vcAZLVxNcmtIDHkvfT+UhTab4fXLN2S
;;; FXxH/9OV25qUPWnSltoDMYIB5jCCAeICAQEwgYwweDELMAkGA1UEBhMCVVMxDjAM
;;; BgNVBAgMBVRleGFzMRAwDgYDVQQHDAdIb3VzdG9uMREwDwYDVQQKDAhTU0wgQ29y
;;; cDE0MDIGA1UEAwwrU1NMLmNvbSBDb2RlIFNpZ25pbmcgSW50ZXJtZWRpYXRlIENB
;;; IEVDQyBSMgIQY41ujedUudgLItW1oB6uMTAMBggqhkjOPQQDAwUAMAsGByqGSM49
;;; AgEFAARmMGQCMF7pyYW+sZQUEFMDwfeWa9H4iLjqBXheGt00FgQ4cSCfzdRasGo7
;;; b9thHynoxjIMzgIwfazQNH2nioeBkEq1bE6HvS2s7IzqKfBRQBrGemfFa/GVNaZo
;;; guWtuRDh1CJhYei3oYHKMIHHBgNVHQ4xgb8Egbw4ADMAOwAxADAALwAyADEALwAy
;;; ADAAMgA2AC8AMgAvADQANwAvADQAMAAvAE4AYQB0AGkAbwBuAGEAbAAgAEkAbgBz
;;; AHQAaQB0AHUAdABlACAAbwBmACAAUwB0AGEAbgBkAGEAcgBkAHMAIABhAG4AZAAg
;;; AFQAZQBjAGgAbgBvAGwAbwBnAHkAIAAoAHQAaQBtAGUALQBhAC4AbgBpAHMAdAAu
;;; AGcAbwB2ACkATABzAHAATABvAGEAZAAAAAAA
;;; -----END-SIGNATURE-----