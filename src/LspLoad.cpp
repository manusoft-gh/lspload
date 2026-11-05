#define STRICT

#ifdef _DEBUG
#define _DEBUG_TEMP_OVERRIDE
#undef _DEBUG
#endif

#include <windows.h>
#include "aced.h"
#include "acdocman.h"
#include "rxregsvc.h"

#ifdef _DEBUG_TEMP_OVERRIDE
#define _DEBUG
#endif

#pragma comment (linker, "/align:4096") //Minimize executable size

#ifdef _ZRXTARGET
#define acrxEntryPoint zcrxEntryPoint
#define ads_queueexpr zds_queueexpr
#endif

#ifdef _GRXTARGET
#define acrxEntryPoint gcrxEntryPoint
#endif

//macros to use version independent ACHAR type
#if (_ACADTARGET <= 16)
typedef char ACHAR;
#define ACRX_T(x) x
#endif
typedef ACHAR* LPACRXSTR;
typedef const ACHAR* LPCACRXSTR;


// Function prototypes
BOOL APIENTRY DllMain( HANDLE hModule, DWORD ul_reason_for_call, LPVOID lpReserved );
AcRx::AppRetCode acrxEntryPoint( AcRx::AppMsgCode msg, void* pkt );
void LoadLsp( LPCACRXSTR pszLspFilename = NULL );
void DefineAdsFunctions();
void InvokeAdsFunction();
void AdsGetPath();
LPCACRXSTR NameOfLspLoadFunction();
LPCACRXSTR NameOfGetPathFunction();
LPCACRXSTR GetTargetFilename();

#if (_ACADTARGET < 18)
extern "C" int ads_queueexpr( LPCACRXSTR );
#endif


// Global variables
HINSTANCE _hdllInstance;

// Function implementations
BOOL APIENTRY DllMain( HANDLE hModule, 
											 DWORD ul_reason_for_call, 
											 LPVOID lpReserved )
{
	if( ul_reason_for_call == DLL_PROCESS_ATTACH )
		_hdllInstance = (HINSTANCE)hModule;
	return TRUE;
}


AcRx::AppRetCode acrxEntryPoint( AcRx::AppMsgCode msg, void* pkt)
{
	switch( msg )
	{
		case AcRx::kInitAppMsg:
			acrxUnlockApplication( pkt );
			acrxDynamicLinker->registerAppMDIAware( pkt );
			break;
		case AcRx::kInvkSubrMsg:
			InvokeAdsFunction();
			break;
		case AcRx::kLoadDwgMsg:
			DefineAdsFunctions();
			break;
		case AcRx::kUnloadDwgMsg:
			break;
		case AcRx::kUnloadAppMsg:
			break;
		case AcRx::kSaveMsg:
			break;
		case AcRx::kEndMsg:
			break;
		case AcRx::kQuitMsg:
			break;
		case AcRx::kCfgMsg:
			break;
		default:
			break;
	}
	return AcRx::kRetOK;
}


void LoadLsp( LPCACRXSTR pszLspFilename /*= NULL*/ )
{
	ACHAR szPath[210] = ACRX_T("");
	::GetModuleFileName( _hdllInstance, szPath, MAX_PATH );
	ACHAR* pCursor;
	for( pCursor = szPath; *pCursor != ACRX_T('\0'); pCursor++ )
	{
		if( *pCursor == ACRX_T('\\') )
			*pCursor = ACRX_T('/');
	}
	int idxSearch = lstrlen( szPath ) - 1;
	for( ; idxSearch >= 0; idxSearch-- )
	{
		if( szPath[idxSearch] == ACRX_T('/') ||
				szPath[idxSearch] == ACRX_T(':') )
			break;
	}
	idxSearch++;
	if( pszLspFilename )
		lstrcpy( szPath + idxSearch, pszLspFilename );
	else
	{
		pCursor = szPath + idxSearch;
		while( *pCursor && *(++pCursor) != ACRX_T('.') );
		if( *pCursor == ACRX_T('.') )
			*pCursor = ACRX_T('\0');
	}
	//ads_queueexpr( ACRX_T("(vl-load-com)") );
	ACHAR szExecuteString[255] = ACRX_T("(vl-load-all \"");
	lstrcat( szExecuteString, szPath );
	lstrcat( szExecuteString, ACRX_T("\")(princ)\n") );
	ads_queueexpr( szExecuteString );
}


void DefineAdsFunctions()
{
	static bool bFirstTime = true;
	if( bFirstTime )
	{
		bFirstTime = false;
		acedDefun( NameOfLspLoadFunction(), 1 );
		ACHAR szLoadLspExpression[MAX_PATH + 64] = ACRX_T("(");
		lstrcat( szLoadLspExpression, NameOfLspLoadFunction() );
		lstrcat( szLoadLspExpression, ACRX_T(")") );
		ads_queueexpr( szLoadLspExpression );
	}
	acedDefun( NameOfGetPathFunction(), 2 );
}


void InvokeAdsFunction()
{
	switch( acedGetFunCode() )
	{
		case 1:
			acedUndef( NameOfLspLoadFunction(), 1 );
			LoadLsp();
			acedRetList( NULL );
			break;
		default:
			AdsGetPath();
			break;
	}
}


void AdsGetPath()
{
	static ACHAR szPath[MAX_PATH] = ACRX_T("");
	if( szPath[0] == ACRX_T('\0') )
	{
		::GetModuleFileName( _hdllInstance, szPath, MAX_PATH );
		ACHAR* pCursor = szPath;
		int idxSearch = lstrlen( szPath ) - 1;
		for( ; idxSearch >= 0; idxSearch-- )
		{
			if( szPath[idxSearch] == ACRX_T('\\') ||
					szPath[idxSearch] == ACRX_T('/') ||
					szPath[idxSearch] == ACRX_T(':') )
				break;
		}
		szPath[++idxSearch] = ACRX_T('\0');
	}
	acedRetStr( szPath );
}


LPCACRXSTR NameOfLspLoadFunction()
{
	static ACHAR szLspLoadFunctionName[MAX_PATH + 16] = ACRX_T("LspLoad-");
	static bool bInitialized = false;
	if( !bInitialized )
	{
		lstrcat( szLspLoadFunctionName, GetTargetFilename() );
		bInitialized = true;
	}
	return szLspLoadFunctionName;
}


LPCACRXSTR NameOfGetPathFunction()
{
	static ACHAR szGetPathFunctionName[MAX_PATH + 16] = ACRX_T("GetPathOf");
	static bool bInitialized = false;
	if( !bInitialized )
	{
		lstrcat( szGetPathFunctionName, GetTargetFilename() );
		bInitialized = true;
	}
	return szGetPathFunctionName;
}


LPCACRXSTR GetTargetFilename()
{
	//return path and filename (sans extension) to use as the lisp target file
	static ACHAR szFilename[MAX_PATH] = ACRX_T("");
	if( szFilename[0] == ACRX_T('\0') )
	{
		ACHAR szPath[MAX_PATH];
		::GetModuleFileName( _hdllInstance, szPath, MAX_PATH );
		int idxSearch = lstrlen( szPath ) - 1;
		for( ; idxSearch >= 0; idxSearch-- )
		{
			if( szPath[idxSearch] == ACRX_T('.') )
			{
				szPath[idxSearch] = ACRX_T('\0');
				continue;
			}
			if( szPath[idxSearch] == ACRX_T('\\') ||
					szPath[idxSearch] == ACRX_T('/') ||
					szPath[idxSearch] == ACRX_T(':') )
				break;
		}
		idxSearch++;
		lstrcpy( szFilename, szPath + idxSearch );
	}
	return szFilename;
}
