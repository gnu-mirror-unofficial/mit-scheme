/* -*-C-*-

$Id: nt.h,v 1.8 1999/01/02 06:11:34 cph Exp $

Copyright (c) 1993-1999 Massachusetts Institute of Technology

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

/* NT system include file */

#ifndef SCM_NT_H
#define SCM_NT_H

#define SYSTEM_NAME "NT"
#define SYSTEM_VARIANT "Windows-NT"

#include <windows.h>
#include <sys/types.h>

#include <io.h>
#include <conio.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <direct.h>
#include <signal.h>
#include <errno.h>

#include <fcntl.h>

enum windows_type { wintype_unknown, wintype_31, wintype_95, wintype_nt };
extern enum windows_type NT_windows_type;

#ifndef ERRNO_NONBLOCK
#define ERRNO_NONBLOCK	1998
#endif
#ifndef EINTR
#define EINTR		1999
#endif

#include "oscond.h"
#include "ansidecl.h"
#include "posixtyp.h"

#include "intext.h"
#include "dstack.h"
#include "osscheme.h"
#include "ntsys.h"
#include "syscall.h"
#include "ntapi.h"
#include <limits.h>
#include <time.h>

/* Crufty, but it will work here. */
#ifndef ENOSYS
#define ENOSYS 0
#endif

/* constants for access() */
#ifndef R_OK
#define R_OK 4
#define W_OK 2
#define X_OK 1
#define F_OK 0
#endif

#ifndef MAXPATHLEN
#define MAXPATHLEN 128
#endif

#ifdef __STDC__
#define ALERT_CHAR '\a'
#define ALERT_STRING "\a"
#else
#define ALERT_CHAR '\007'
#define ALERT_STRING "\007"
#endif

#ifndef GUI
  extern HANDLE  STDIN_HANDLE,  STDOUT_HANDLE,  STDERR_HANDLE;
#endif

/* constants for open() and fcntl() */
#ifndef O_RDONLY
#define O_RDONLY 0
#define O_WRONLY 1
#define O_RDWR 2
#endif

/* mode bit definitions for open(), creat(), and chmod() */
#ifndef S_IRWXU
#define S_IRWXU 0700
#define S_IRWXG 0070
#define S_IRWXO 0007
#endif

#ifndef S_IRUSR
#define S_IRUSR 0400
#define S_IWUSR 0200
#define S_IXUSR 0100
#define S_IRGRP 0040
#define S_IWGRP 0020
#define S_IXGRP 0010
#define S_IROTH 0004
#define S_IWOTH 0002
#define S_IXOTH 0001
#endif

#define MODE_REG (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH)
#define MODE_DIR (MODE_REG | S_IXUSR | S_IXGRP | S_IXOTH)

/* constants for lseek() */
#ifndef SEEK_SET
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2
#endif

#ifndef DECL_GETLOGIN
extern char * EXFUN (getlogin, (void));
#endif

#ifndef WINNT
extern PTR EXFUN (malloc, (unsigned int size));
extern PTR EXFUN (realloc, (PTR ptr, unsigned int size));
extern int EXFUN (gethostname, (char * name, unsigned int size));
#endif

#ifdef _NFILE
#define NT_SC_OPEN_MAX() _NFILE
#else
#define NT_SC_OPEN_MAX() 16
#endif

#endif /* SCM_NT_H */
