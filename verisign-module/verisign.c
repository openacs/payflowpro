/*
*
*   Module     :   Verisign.c
*
*   Author     :   Brad Duell (bduell@ncacasi.org)
*                  Modified for my needs by Janine Sisk (janine*furfly.net)
*   Date       :   October 15th, 2001
*                  Modifications done February, 2002
*   Description:   Augmentation of cybercash.c Aolserver module, originally
*                   designed by ArsDigita, LLC and Jin S. Choi.  Use of
*                   same procedural names, using the VeriSign PayFlowPro v.3.00
*                   payment processing interface instead.
*   Notes      :  
* 
*	 defines three Tcl procedures for the AOLserver API:
*   cc_generate_order_id, returns a unique order ID (not useful if you
*	 are generating keys with an Oracle sequence or whatever)
*   cc_send_to_server_21, access to the direct VeriSign API documented 
*	 in the PayFlow Pro (Version 3.00) Developer's Guide.
*   cc_do_direct_payment, access to the directpaycredit facility documented 
*	 in the PayFlow Pro (Version 3.00) Developer's Guide.
*
*                             COPYRIGHT NOTICE
*
*   this software is copyright 2001 by North Central Association CASI
*	 it is distributed free under the GNU General Public License
*
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ns.h"
#include "pfpro.c"

/***** YOU SHOULD ONLY HAVE TO EDIT THE FOLLOWING GLOBALS */
char *USER        = "USERNAME";
char *PARTNER     = "PARTNERNAME";
char *PWD         = "PASSWORD";
char *CERTPATH    = "PFPRO_CERT_PATH=PATH_TO_YOUR_PFPROCERT(S)";
char *hostAddress = "payflow.verisign.com";
int  portNum	  = 443;
/***** NOTHING BELOW THIS LINE SHOULD HAVE TO BE EDITED */

DllExport int Ns_ModuleVersion = 1;
static Tcl_CmdProc GenerateOrderIDCmd;
static Tcl_CmdProc SendToServer21Cmd;

int CC_SUCCESS = 0;

static int
GenerateOrderIDCmd(ClientData dummy, Tcl_Interp *interp, int argc, char **argv)
{
  struct tm* timerec;
  pid_t	   mypid;
  time_t	   mytime;

  if (argc != 1) {
	 interp->result = "Usage: cc_generate_order_id";
	 return TCL_ERROR;
  }

  mytime = time((time_t *) NULL);
  mypid = getpid();
  timerec = gmtime(&mytime);
  
  sprintf(interp->result,"%02d%02d%02d%02d%02d%05d",
          timerec->tm_year, timerec->tm_mon + 1, timerec->tm_mday,
          timerec->tm_hour, timerec->tm_min,
          mypid);
  return TCL_OK;
}

/**
 * Takes two ns_set's, input and output.
 * Output set is filled with result values.
 */
static int
SendToServer21Cmd(ClientData dummy, Tcl_Interp *interp, int argc, char **argv)
{
  long timeout			       = 30;
  char *proxyAddress	       = NULL;
  int  proxyPort		       = 0;
  char *proxyLogon		    = NULL;
  char *proxyPassword	    = NULL;
  int	 rc,i,context,parmLen;
  char rcBuf[1000];
  char *tranResponse;

  /* Arguments to be send to the PayFlowPro server. */
  char parmList[1000]       = "USER=";
  char str[1000];
  char *AMT                 = NULL;
  char *ACCT                = NULL;
  char *EXPDATEWHOLE        = NULL;
  char *EXPDATE             = NULL;
  char *ZIP                 = NULL;
  char *STREET              = NULL;
  char *NAME                = NULL;
  char *ORIGID              = NULL;

  /* From the Payflow Pro (v. 3.00) Developer's Guide Transaction Responses. */
/*  char *respRESULT          = "1000"; */
  char respPNREF[100];
  char respRESPMSG[100];
  char respAUTHCODE[100];
  char respAVSADDR[2];
  char respAVSZIP[2];
  char *marker = NULL;

  /* The output set that the ACS expects to read from. */
  Ns_Set *output;

  if (!(argc <= 4) && (argc > 5)) {
	 /* We'll allow 5 arguments in case we're doing test runs... */
	 /* In which case the 5th could be an alternate server. */
	 interp->result = "Usage: cc_send_to_server_21 <command> <input ns_set> <output ns_set>";
	 return TCL_ERROR;
  }
  if (argc == 5) {
	 hostAddress = argv[4];
  }

  output = Ns_TclGetSet(interp, argv[3]);
  if (output == NULL) {
	 interp->result = "Output was not a valid ns_set";
	 return TCL_ERROR;
  }

  strcat(parmList, USER);
  strcat(parmList, "&VENDOR=");
  strcat(parmList, USER);
  strcat(parmList, "&PARTNER=");
  strcat(parmList, PARTNER);
  strcat(parmList, "&PWD=");
  strcat(parmList, PWD);
  strcat(parmList, "&TRXTYPE=");

  /* Let's determine the type of transaction. */
  if (!strcmp(argv[1], "mauthonly") || !strcmp(argv[1], "retry")) {
	 strcat(parmList, "A");
  } else {
	 if (!strcmp(argv[1], "charge")) {
		strcat(parmList, "S");
	 } else {
	        if (!strcmp(argv[1], "postauth")) {
		       strcat(parmList, "D");
	        } else {
		       if (!strcmp(argv[1], "return")) {
		         strcat(parmList, "C");
		       } else {
		         if (!strcmp(argv[1], "void")) {
			        strcat(parmList, "V");
		         } else {
			        interp->result = "Module does not support or cannot determine transaction type.";
			        return TCL_ERROR;
		         }
		      }
		}
	 }
  }

  /* For each item, throw an error only if the value is required 
     and missing.  */

  /* Here we'll pull the amount of the transaction. */
  strcat(parmList, "&TENDER=C");
  AMT = Ns_SetGet((Ns_TclGetSet(interp, argv[2])), "amount");
  if (AMT == NULL) {
    if (!strcmp(argv[1],"charge") || !strcmp(argv[1],"mauthonly")) {
	 interp->result = "Cannot retrieve tender amount.";
	 return TCL_ERROR;
    }
  } else {
    sprintf(str,"&AMT=%s",AMT);
    strcat(parmList,str);
  }

  /* Now we'll grab the street, adding the length to allow or
     & or = in the street name.. */
  STREET = Ns_SetGet((Ns_TclGetSet(interp, argv[2])), "card-street");
  if (STREET != NULL) {
      sprintf(str,"&STREET[%d]=%s",strlen(STREET),STREET);
      strcat(parmList, str);
  }

  /* Now we'll grab the zip. */
  ZIP = Ns_SetGet((Ns_TclGetSet(interp, argv[2])), "card-zip");
  if (ZIP != NULL) {
      sprintf(str,"&ZIP=%s",ZIP);
      strcat(parmList, str);
  }

  /* And the name on the card, also allowing for & and = */
  NAME = Ns_SetGet((Ns_TclGetSet(interp, argv[2])), "card-name");
  if (NAME != NULL) {
      sprintf(str,"&NAME[%d]=%s",strlen(NAME),NAME);
      strcat(parmList, str);
  }

  /* Now we'll grab the card number. */
  ACCT = Ns_SetGet((Ns_TclGetSet(interp, argv[2])), "card-number");
  if (ACCT == NULL) {
    if (!strcmp(argv[1],"charge") || !strcmp(argv[1],"mauthonly")) {
	 interp->result = "Cannot retrieve account number.";
	 return TCL_ERROR;
    }
  } else {
    sprintf(str,"&ACCT=%s",ACCT);
    strcat(parmList, str);
  }

  /* Now for the expiration date, seperated by a '/'. */
  EXPDATEWHOLE = Ns_SetGet((Ns_TclGetSet(interp, argv[2])), "card-exp");
  if (EXPDATEWHOLE == NULL) {
    if (!strcmp(argv[1],"charge") || !strcmp(argv[1],"mauthonly")) {
	 interp->result = "Cannot retrieve account expiration date.";
	 return TCL_ERROR;
    }
  } else {
    EXPDATE=strtok(EXPDATEWHOLE, "/");
    if (EXPDATE == NULL) {
      sprintf(str,"&EXPDATE=%s",EXPDATEWHOLE);
      strcat(parmList, str);
    } else {
      sprintf(str,"&EXPDATE=%s",EXPDATE);
      strcat(parmList, str);
      EXPDATE=strtok(NULL, "/");
      strcat(parmList, EXPDATE);
    }
  }

  /* Now for the transaction_id/order_id. */
  ORIGID = Ns_SetGet((Ns_TclGetSet(interp, argv[2])), "order-id");
  if (ORIGID == NULL) {
    if (!strcmp(argv[1],"postauth") || !strcmp(argv[1],"return") || !strcmp(argv[1],"void")) {
	 interp->result = "Cannot retrieve reference id.";
	 return TCL_ERROR;
    }
  } else {
    sprintf(str,"&ORIGID=%s",ORIGID);
    strcat(parmList, str);
  }
Ns_Log(Notice,"J9: parmList = %s", parmList);

  /* Initialize PayFlowPro client. */
  if( pfproInit() ) {
	 interp->result = "Failed to initialize PayFlowPro client.";
	 return TCL_ERROR;
  }
  if( pfproCreateContext(&context, hostAddress, portNum, timeout, proxyAddress, proxyPort, proxyLogon, proxyPassword)) {
	 interp->result = "Failed to create PayFlowPro context.";
	 return TCL_ERROR;
  }
  parmLen = strlen(parmList);

  /* Nullify the end of the parameter list. */
  parmList[parmLen] = '\0';
  
  /* Submit Transaction. */
  pfproSubmitTransaction(context, parmList, parmLen, &tranResponse);

Ns_Log(Notice,"J9: tranResponse = %s", tranResponse);

  /* Get the result code. */
  marker = strstr(tranResponse,"RESULT=");
  if (marker) {
	 i = 0;
	 marker+=7;
	 while ((*marker != '&') && (i<=2)) {
		rcBuf[i]=*marker;
		marker++;
		i++;
	 }
	 rcBuf[i] = 0;
	 rc = atoi(rcBuf);
  } else
	 rc = 1;

  /* Get the response message. */
  marker = strstr(tranResponse,"RESPMSG=");
  if (marker) {
	 i = 0;
	 marker+=8;
	 while ((*marker != '&') && (*marker != '\0')) {
		rcBuf[i]=*marker;
		marker++;
		i++;
	 }
	 rcBuf[i] = 0;
	 strcpy(respRESPMSG, rcBuf);
  } else
      respRESPMSG[0] = '\0';

  /* Get a reference number for this transaction. */
  marker = strstr(tranResponse,"PNREF=");
  if (marker) {
	 i = 0;
	 marker+=6;
	 while ((*marker != '&') && (*marker != '\0')) {
		rcBuf[i]=*marker;
		marker++;
		i++;
	 }
	 rcBuf[i] = 0;
	 strcpy(respPNREF, rcBuf);
  } else
      respPNREF[0] = '\0';

  if (rc == 0) {
	 /* Approved */

	 /* Get the authentication code. */
	 marker = strstr(tranResponse,"AUTHCODE=");
	 if (marker) {
		i = 0;
		marker+=9;
		while ((*marker != '&') && (*marker != '\0')) {
		  rcBuf[i]=*marker;
		  marker++;
		  i++;
		}
		rcBuf[i] = 0;
		strcpy(respAUTHCODE, rcBuf);
	 } else 
             respAUTHCODE[0] = '\0';

	 /* Get any AVS available. */
	 marker = strstr(tranResponse,"AVSZIP=");
	 if (marker) {
		i = 0;
		marker+=7;
		while ((*marker != '&') && (*marker != '\0')) {
		  rcBuf[i]=*marker;
		  marker++;
		  i++;
	 }
		rcBuf[i] = 0;
		strcpy(respAVSZIP, rcBuf);
	 } else
             respAVSZIP[0] = '\0';
	 
	 marker = strstr(tranResponse,"AVSADDR=");
	 if (marker) {
		i = 0;
		marker+=8;
		while ((*marker != '&') && (*marker != '\0')) {
		  rcBuf[i]=*marker;
		  marker++;
		  i++;
		}
		rcBuf[i] = 0;
		strcpy(respAVSADDR, rcBuf);
	 } else
             respAVSADDR[0] = '\0';
	 
	 /* We know it's a success.  Just return applicable codes. */
	 Ns_SetPut(output, "MStatus", "success");
	 if (!strcmp(argv[1], "mauthonly") || !strcmp(argv[1], "charge") || !strcmp(argv[1], "retry")) {
		Ns_SetPut(output, "aux-msg", respRESPMSG);
		Ns_SetPut(output, "auth-code", respAUTHCODE);
		Ns_SetPut(output, "action-code", "000");
		Ns_SetPut(output, "merch-txn", respPNREF);
		if (strlen(respAVSADDR) == 0) {
		  if (strlen(respAVSZIP) == 0) {
			 Ns_SetPut(output, "avs-code", "Z");
		  } else {
			 Ns_SetPut(output, "avs-code", respAVSZIP);
		  }
		} else {
		  Ns_SetPut(output, "avs-code", respAVSADDR);
		}
	 } else {
		Ns_SetPut(output, "merch-txn", respPNREF);
		Ns_SetPut(output, "aux-msg", respRESPMSG);
	 }

	 /* Complete the transaction. */
	 pfproCompleteTransaction(tranResponse);
	 pfproDestroyContext(context);
  } else {
	 /* Declined.  There are a lot of reasons why, but only a few we care about. */
	 if (rc == 50 || rc == 23 || rc == 13 || rc == 24 || rc == 2 || rc == 12) {
	   /* Insufficent Funds or account number problems */
	   Ns_SetPut(output, "MStatus", "failure-bad-money");
	 } else {
	   if (rc < 0 || (rc >= 100 && rc <= 104) || rc == 106) {
	     /* Various communications errors */
	     Ns_SetPut(output, "MStatus", "failure-q-or-cancel");
	   } else {
	     /* Default Error Response */
	     Ns_SetPut(output, "MStatus", "failure-hard");
	   }
	 }
		
	 /* All of These Errors Get Returned */
	 Ns_SetPut(output, "MErrLoc", "smps");
	 Ns_SetPut(output, "MErrMsg", respRESPMSG);
	 Ns_SetPut(output, "merch-txn", respPNREF);
  }

  pfproCleanup();

Ns_Log(Notice,"J9 Leaving verisign.so: MStatus=%s,MErrMsg=%s,merch-txn=%s",Ns_SetGet(output, "MStatus"),Ns_SetGet(output,"MErrMsg"),Ns_SetGet(output,"merch-txn"));

  return TCL_OK;
}

/**
 * This implementation is included in the SendToServer21Cmd function
 * and is included here for compatibility
*/
static int
DirectPaymentCmd(ClientData dummy, Tcl_Interp *interp, int argc, char **argv)
{
  if (SendToServer21Cmd(dummy, interp, argc, argv)) {
	 return TCL_OK;
  } else {
	 return TCL_ERROR;
  }
}

static int
VerisignInterpInit(Tcl_Interp *interp, void *context) 
{  
  Tcl_CreateCommand(interp, "cc_generate_order_id", GenerateOrderIDCmd, NULL, NULL);
  Tcl_CreateCommand(interp, "cc_send_to_server_21", SendToServer21Cmd, NULL, NULL);
  Tcl_CreateCommand(interp, "cc_do_direct_payment", DirectPaymentCmd, NULL, NULL);
  
  putenv(CERTPATH);

  return NS_OK;
}

/*
 * This structure is used to pass the critical section
 * and enter and leave command names to InitCs function
 * through the Ns_TclInitInterps function.
 */
typedef struct {
  char *enter;
  char *leave;
  Ns_CriticalSection *cs;
} CsCtx;

int
Ns_ModuleInit(char *hServer, char *hModule)
{
  CsCtx ctx;
  int status;

  status = Ns_TclInitInterps(hServer, VerisignInterpInit, (void *) &ctx);

  return status;
}
