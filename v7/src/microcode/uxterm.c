/* -*-C-*-

$Id: uxterm.c,v 1.26 1999/01/02 06:11:34 cph Exp $

Copyright (c) 1990-1999 Massachusetts Institute of Technology

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

#include "ux.h"
#include "uxterm.h"
#include "uxio.h"
#include "ospty.h"

#if defined(HAVE_TERMIOS) || defined(HAVE_TERMIO)

#ifndef ISTRIP
#define ISTRIP 0
#endif
#ifndef CS8
#define CS8 0
#endif
#ifndef PARENB
#define PARENB 0
#endif

#else
#ifdef HAVE_BSD_TTY_DRIVER

/* LPASS8 is new in 4.3, and makes cbreak mode provide all 8 bits.  */
#ifndef LPASS8
#define LPASS8 0
#endif

#endif /* HAVE_BSD_TTY_DRIVER */
#endif /* not HAVE_TERMIOS nor HAVE_TERMIO */

struct terminal_state
{
  int buffer;
  Ttty_state state;
};

static struct terminal_state * terminal_table;
#define TERMINAL_BUFFER(channel) ((terminal_table[(channel)]) . buffer)
#define TERMINAL_ORIGINAL_STATE(channel) ((terminal_table[(channel)]) . state)

#if defined(HAVE_TERMIOS) || defined(HAVE_TERMIO)
#define TIO(s) (& ((s) -> tio))
#endif

void
DEFUN_VOID (UX_initialize_terminals)
{
  terminal_table =
    (UX_malloc (OS_channel_table_size * (sizeof (struct terminal_state))));
  if (terminal_table == 0)
    {
      fprintf (stderr, "\nUnable to allocate terminal table.\n");
      fflush (stderr);
      termination_init_error ();
    }
}

void
DEFUN_VOID (UX_reset_terminals)
{
  UX_free (terminal_table);
  terminal_table = 0;
}

/* This is called from the file-opening code. */
void
DEFUN (terminal_open, (channel), Tchannel channel)
{
  (TERMINAL_BUFFER (channel)) = (-1);
  get_terminal_state (channel, (& (TERMINAL_ORIGINAL_STATE (channel))));
}

void
DEFUN (get_terminal_state, (channel, s), Tchannel channel AND Ttty_state * s)
{
  STD_VOID_SYSTEM_CALL
    (syscall_terminal_get_state,
     (UX_terminal_get_state ((CHANNEL_DESCRIPTOR (channel)), s)));
}

void
DEFUN (set_terminal_state, (channel, s), Tchannel channel AND Ttty_state * s)
{
  extern int EXFUN (UX_terminal_control_ok, (int fd));
  if (UX_terminal_control_ok (CHANNEL_DESCRIPTOR (channel)))
    STD_VOID_SYSTEM_CALL
      (syscall_terminal_set_state,
       (UX_terminal_set_state ((CHANNEL_DESCRIPTOR (channel)), s)));
}

unsigned int
DEFUN (terminal_state_get_ospeed, (s), Ttty_state * s)
{
#ifdef HAVE_TERMIOS
  return (cfgetospeed (TIO (s)));
#else
#ifdef HAVE_TERMIO
  return (((TIO (s)) -> c_cflag) & CBAUD);
#else
#ifdef HAVE_BSD_TTY_DRIVER
  return (s -> sg . sg_ospeed);
#endif /* HAVE_BSD_TTY_DRIVER */
#endif /* not HAVE_TERMIO */
#endif /* not HAVE_TERMIOS */
}

unsigned int
DEFUN (terminal_state_get_ispeed, (s), Ttty_state * s)
{
#ifdef HAVE_TERMIOS
  return (cfgetispeed (TIO (s)));
#else
#ifdef HAVE_TERMIO
  return (((TIO (s)) -> c_cflag) & CBAUD);
#else
#ifdef HAVE_BSD_TTY_DRIVER
  return (s -> sg . sg_ispeed);
#endif /* HAVE_BSD_TTY_DRIVER */
#endif /* not HAVE_TERMIO */
#endif /* not HAVE_TERMIOS */
}

void
DEFUN (terminal_state_set_ospeed, (s, b),
       Ttty_state * s AND
       unsigned int b)
{
#ifdef HAVE_TERMIOS
  cfsetospeed ((TIO (s)), b);
#else
#ifdef HAVE_TERMIO
  ((TIO (s)) -> c_cflag) = ((((TIO (s)) -> c_cflag) &~ CBAUD) | b);
#else
#ifdef HAVE_BSD_TTY_DRIVER
  (s -> sg . sg_ospeed) = b;
#endif /* HAVE_BSD_TTY_DRIVER */
#endif /* not HAVE_TERMIO */
#endif /* not HAVE_TERMIOS */
}

void
DEFUN (terminal_state_set_ispeed, (s, b),
       Ttty_state * s AND
       unsigned int b)
{
#ifdef HAVE_TERMIOS
  cfsetispeed ((TIO (s)), b);
#else
#ifdef HAVE_TERMIO
  ((TIO (s)) -> c_cflag) =
    ((((TIO (s)) -> c_cflag) &~ CIBAUD) | (b << IBSHIFT));
#else
#ifdef HAVE_BSD_TTY_DRIVER
  (s -> sg . sg_ispeed) = b;
#endif /* HAVE_BSD_TTY_DRIVER */
#endif /* not HAVE_TERMIO */
#endif /* not HAVE_TERMIOS */
}

int
DEFUN (terminal_state_cooked_output_p, (s), Ttty_state * s)
{
#if defined(HAVE_TERMIOS) || defined(HAVE_TERMIO)
  return ((((TIO (s)) -> c_oflag) & OPOST) != 0);
#else /* not HAVE_TERMIOS nor HAVE_TERMIO */
#ifdef HAVE_BSD_TTY_DRIVER
  return (((s -> sg . sg_flags) & LLITOUT) == 0);
#endif /* HAVE_BSD_TTY_DRIVER */
#endif /* HAVE_TERMIOS or HAVE_TERMIO */
}

void
DEFUN (terminal_state_raw_output, (s), Ttty_state * s)
{
#if defined(HAVE_TERMIOS) || defined(HAVE_TERMIO)
  ((TIO (s)) -> c_oflag) &=~ OPOST;
#else /* not HAVE_TERMIOS nor HAVE_TERMIO */
#ifdef HAVE_BSD_TTY_DRIVER
  (s -> sg . sg_flags) &=~ ALLDELAY;
  (s -> lmode) |= LLITOUT;
#endif /* HAVE_BSD_TTY_DRIVER */
#endif /* HAVE_TERMIOS or HAVE_TERMIO */
}

void
DEFUN (terminal_state_cooked_output, (s, channel),
       Ttty_state * s AND Tchannel channel)
{
  Ttty_state * os = (& (TERMINAL_ORIGINAL_STATE (channel)));
#if defined(HAVE_TERMIOS) || defined(HAVE_TERMIO)
  ((TIO (s)) -> c_oflag) |= (((TIO (os)) -> c_oflag) & OPOST);
#else /* not HAVE_TERMIOS nor HAVE_TERMIO */
#ifdef HAVE_BSD_TTY_DRIVER
  (s -> sg . sg_flags) =
    (((s -> sg . sg_flags) &~ ALLDELAY) | ((os -> sg . sg_flags) & ALLDELAY));
  (s -> lmode) &=~ ((os -> lmode) & LLITOUT);
#endif /* HAVE_BSD_TTY_DRIVER */
#endif /* HAVE_TERMIOS or HAVE_TERMIO */
}

int
DEFUN (terminal_state_buffered_p, (s), Ttty_state * s)
{
#if defined(HAVE_TERMIOS) || defined(HAVE_TERMIO)
  return ((((TIO (s)) -> c_lflag) & ICANON) != 0);
#else /* not HAVE_TERMIOS nor HAVE_TERMIO */
#ifdef HAVE_BSD_TTY_DRIVER
  return (((s -> sg . sg_flags) & (CBREAK | RAW)) == 0);
#endif /* HAVE_BSD_TTY_DRIVER */
#endif /* HAVE_TERMIOS or HAVE_TERMIO */
}

void
DEFUN (terminal_state_nonbuffered, (s, fd, polling),
       Ttty_state * s AND
       int fd AND
       int polling)
{
#if defined(HAVE_TERMIOS) || defined(HAVE_TERMIO)

  ((TIO (s)) -> c_lflag) &=~ (ICANON | ECHO);
#ifdef IEXTEN
  ((TIO (s)) -> c_lflag) &=~ IEXTEN;
#endif
  ((TIO (s)) -> c_lflag) |= ISIG;
  ((TIO (s)) -> c_iflag) |= IGNBRK;
  ((TIO (s)) -> c_iflag) &=~ (ICRNL | IXON | ISTRIP);
  ((TIO (s)) -> c_cflag) |= CS8;
  ((TIO (s)) -> c_cflag) &=~ PARENB;
  (((TIO (s)) -> c_cc) [VMIN]) = (polling ? 0 : 1);
  (((TIO (s)) -> c_cc) [VTIME]) = 0;
#ifdef HAVE_TERMIOS
  {
    cc_t disable = (UX_PC_VDISABLE (fd));
    (((TIO (s)) -> c_cc) [VSTOP]) = disable;
    (((TIO (s)) -> c_cc) [VSTART]) = disable;
  }
#endif

#else /* not HAVE_TERMIOS nor HAVE_TERMIO */
#ifdef HAVE_BSD_TTY_DRIVER

  (s -> sg . sg_flags) &=~ (ECHO | CRMOD);
  (s -> sg . sg_flags) |= (ANYP | CBREAK);
  (s -> lmode) |= (LPASS8 | LNOFLSH);
  (s -> tc . t_startc) = (-1);
  (s -> tc . t_stopc) = (-1);
  (s -> tc . t_eofc) = (-1);
  (s -> tc . t_brkc) = (-1);
#ifdef HAVE_BSD_JOB_CONTROL
  (s -> ltc . t_rprntc) = (-1);
  (s -> ltc . t_flushc) = (-1);
  (s -> ltc . t_werasc) = (-1);
  (s -> ltc . t_lnextc) = (-1);
#endif /* HAVE_BSD_JOB_CONTROL */

#endif /* HAVE_BSD_TTY_DRIVER */
#endif /* HAVE_TERMIOS or HAVE_TERMIO */
}

void
DEFUN (terminal_state_raw, (s, fd), Ttty_state * s AND int fd)
{
  terminal_state_nonbuffered (s, fd, 0);

#if defined(HAVE_TERMIOS) || defined(HAVE_TERMIO)

  ((TIO (s)) -> c_lflag) &=~ ISIG;

#else /* not HAVE_TERMIOS nor HAVE_TERMIO */
#ifdef HAVE_BSD_TTY_DRIVER

  (s -> sg . sg_flags) &=~ CBREAK;
  (s -> sg . sg_flags) |= RAW;
  (s -> tc . t_intrc) = (-1);
  (s -> tc . t_quitc) = (-1);
#ifdef HAVE_BSD_JOB_CONTROL
  (s -> ltc . t_suspc) = (-1);
  (s -> ltc . t_dsuspc) = (-1);
#endif /* HAVE_BSD_JOB_CONTROL */

#endif /* HAVE_BSD_TTY_DRIVER */
#endif /* HAVE_TERMIOS or HAVE_TERMIO */
}

void
DEFUN (terminal_state_buffered, (s, channel),
       Ttty_state * s AND
       Tchannel channel)
{
  Ttty_state * os = (& (TERMINAL_ORIGINAL_STATE (channel)));

#if defined(HAVE_TERMIOS) || defined(HAVE_TERMIO)

  ((TIO (s)) -> c_lflag) |= (ICANON | ISIG);
  ((TIO (s)) -> c_lflag) |= (((TIO (os)) -> c_lflag) & ECHO);
#ifdef IEXTEN
  ((TIO (s)) -> c_lflag) |= (((TIO (os)) -> c_lflag) & IEXTEN);
#endif
  ((TIO (s)) -> c_iflag) = ((TIO (os)) -> c_iflag);
  ((TIO (s)) -> c_cflag) |= CS8;
  ((TIO (s)) -> c_cflag) &=~ PARENB;
  (((TIO (s)) -> c_cc) [VMIN]) = (((TIO (os)) -> c_cc) [VMIN]);
  (((TIO (s)) -> c_cc) [VTIME]) = (((TIO (os)) -> c_cc) [VTIME]);
#ifdef HAVE_TERMIOS
  (((TIO (s)) -> c_cc) [VSTOP]) = (((TIO (os)) -> c_cc) [VSTOP]);
  (((TIO (s)) -> c_cc) [VSTART]) = (((TIO (os)) -> c_cc) [VSTART]);
#endif

#else /* not HAVE_TERMIOS nor HAVE_TERMIO */
#ifdef HAVE_BSD_TTY_DRIVER

  (s -> sg . sg_flags) &=~ (CBREAK | RAW);
  (s -> sg . sg_flags) |= ANYP;
  (s -> sg . sg_flags) |= ((os -> sg . sg_flags) & (ECHO | CRMOD));
  (s -> lmode) &=~ LNOFLSH;
  (s -> lmode) |= LPASS8;
  (s -> tc . t_intrc) = (os -> tc . t_intrc);
  (s -> tc . t_quitc) = (os -> tc . t_quitc);
  (s -> tc . t_startc) = (os -> tc . t_startc);
  (s -> tc . t_stopc) = (os -> tc . t_stopc);
  (s -> tc . t_eofc) = (os -> tc . t_eofc);
  (s -> tc . t_brkc) = (os -> tc . t_brkc);
#ifdef HAVE_BSD_JOB_CONTROL
  (s -> ltc . t_suspc) = (os -> ltc . t_suspc);
  (s -> ltc . t_dsuspc) = (os -> ltc . t_dsuspc);
  (s -> ltc . t_rprntc) = (os -> ltc . t_rprntc);
  (s -> ltc . t_flushc) = (os -> ltc . t_flushc);
  (s -> ltc . t_werasc) = (os -> ltc . t_werasc);
  (s -> ltc . t_lnextc) = (os -> ltc . t_lnextc);
#endif /* HAVE_BSD_JOB_CONTROL */

#endif /* HAVE_BSD_TTY_DRIVER */
#endif /* HAVE_TERMIOS or HAVE_TERMIO */
}

unsigned int
DEFUN (OS_terminal_get_ispeed, (channel), Tchannel channel)
{
  Ttty_state s;
  get_terminal_state (channel, (&s));
  return (terminal_state_get_ispeed (&s));
}

unsigned int
DEFUN (OS_terminal_get_ospeed, (channel), Tchannel channel)
{
  Ttty_state s;
  get_terminal_state (channel, (&s));
  return (terminal_state_get_ospeed (&s));
}

void
DEFUN (OS_terminal_set_ispeed, (channel, baud),
       Tchannel channel AND
       unsigned int baud)
{
  Ttty_state s;
  get_terminal_state (channel, (&s));
  terminal_state_set_ispeed ((&s), baud);
  set_terminal_state (channel, (&s));
}

void
DEFUN (OS_terminal_set_ospeed, (channel, baud),
       Tchannel channel AND
       unsigned int baud)
{
  Ttty_state s;
  get_terminal_state (channel, (&s));
  terminal_state_set_ospeed ((&s), baud);
  set_terminal_state (channel, (&s));
}

#ifndef NO_BAUD_CONVERSION
static unsigned int baud_convert [] =
#ifdef _HPUX
  {
    0, 50, 75, 110, 135, 150, 200, 300, 600, 900, 1200,
    1800, 2400, 3600, 4800, 7200, 9600, 19200, 38400
  };
#else
  {
    0, 50, 75, 110, 135, 150, 200, 300, 600, 1200,
    1800, 2400, 4800, 9600, 19200, 38400
  };
#endif

#define BAUD_CONVERT_LENGTH						\
  ((sizeof (baud_convert)) / (sizeof (baud_convert[0])))
#endif /* NO_BAUD_CONVERSION */

unsigned int
DEFUN (arg_baud_index, (argument), unsigned int argument)
{
#ifdef NO_BAUD_CONVERSION
  return (arg_nonnegative_integer (argument));
#else
  return (arg_index_integer (argument, BAUD_CONVERT_LENGTH));
#endif
}

unsigned int
DEFUN (OS_baud_index_to_rate, (index), unsigned int index)
{
#ifdef NO_BAUD_CONVERSION
  return (index);
#else
  return (baud_convert [index]);
#endif
}

int
DEFUN (OS_baud_rate_to_index, (rate), unsigned int rate)
{
#ifdef NO_BAUD_CONVERSION
  return (rate);
#else
  unsigned int * scan = baud_convert;
  unsigned int * end = (scan + BAUD_CONVERT_LENGTH);
  while (scan < end)
    if ((*scan++) == rate)
      return ((scan - 1) - baud_convert);
  return (-1);
#endif
}

unsigned int
DEFUN_VOID (OS_terminal_state_size)
{
  return (sizeof (Ttty_state));
}

void
DEFUN (OS_terminal_get_state, (channel, statep),
       Tchannel channel AND
       PTR statep)
{
  get_terminal_state (channel, statep);
}

void
DEFUN (OS_terminal_set_state, (channel, statep),
       Tchannel channel AND
       PTR statep)
{
  set_terminal_state (channel, statep);
}

int
DEFUN (OS_terminal_cooked_output_p, (channel), Tchannel channel)
{
  Ttty_state s;
  get_terminal_state (channel, (&s));
  return (terminal_state_cooked_output_p (&s));
}

void
DEFUN (OS_terminal_raw_output, (channel), Tchannel channel)
{
  Ttty_state s;
  get_terminal_state (channel, (&s));
  terminal_state_raw_output (&s);
  set_terminal_state (channel, (&s));
}

void
DEFUN (OS_terminal_cooked_output, (channel), Tchannel channel)
{
  Ttty_state s;
  get_terminal_state (channel, (&s));
  terminal_state_cooked_output ((&s), channel);
  set_terminal_state (channel, (&s));
}

int
DEFUN (OS_terminal_buffered_p, (channel), Tchannel channel)
{
  Ttty_state s;
  get_terminal_state (channel, (&s));
  return (terminal_state_buffered_p (&s));
}

void
DEFUN (OS_terminal_buffered, (channel), Tchannel channel)
{
  Ttty_state s;
  get_terminal_state (channel, (&s));
  terminal_state_buffered ((&s), channel);
  set_terminal_state (channel, (&s));
}

void
DEFUN (OS_terminal_nonbuffered, (channel), Tchannel channel)
{
  Ttty_state s;
  get_terminal_state (channel, (&s));
  terminal_state_nonbuffered ((&s), (CHANNEL_DESCRIPTOR (channel)), 0);
  set_terminal_state (channel, (&s));
}

void
DEFUN (OS_terminal_flush_input, (channel), Tchannel channel)
{
  STD_VOID_SYSTEM_CALL
    (syscall_tcflush, (UX_tcflush ((CHANNEL_DESCRIPTOR (channel)), TCIFLUSH)));
}

void
DEFUN (OS_terminal_flush_output, (channel), Tchannel channel)
{
  STD_VOID_SYSTEM_CALL
    (syscall_tcflush, (UX_tcflush ((CHANNEL_DESCRIPTOR (channel)), TCOFLUSH)));
}

void
DEFUN (OS_terminal_drain_output, (channel), Tchannel channel)
{
  STD_VOID_SYSTEM_CALL
    (syscall_tcdrain, (UX_tcdrain (CHANNEL_DESCRIPTOR (channel))));
}

int
DEFUN_VOID (OS_job_control_p)
{
  return (UX_SC_JOB_CONTROL ());
}

#ifdef HAVE_PTYS

int
DEFUN_VOID (OS_have_ptys_p)
{
  return (1);
}

#ifdef FIRST_PTY_LETTER

#define PTY_DECLARATIONS						\
  int c;								\
  int i

#define PTY_ITERATION							\
  for (c = FIRST_PTY_LETTER; (c <= 'z'); c += 1)			\
    for (i = 0; (i < 16); i += 1)

#define PTY_MASTER_NAME_SPRINTF(master_name)				\
  sprintf ((master_name), "/dev/pty%c%x", c, i)

#define PTY_SLAVE_NAME_SPRINTF(slave_name, fd)				\
{									\
  sprintf ((slave_name), "/dev/tty%c%x", c, i);				\
  if ((UX_access ((slave_name), (R_OK | W_OK))) < 0)			\
    {									\
      UX_close (fd);							\
      continue;								\
    }									\
}

#endif /* FIRST_PTY_LETTER */

/* Open an available pty, putting channel in (*ptyv),
   and return the file name of the pty.
   Signal error if none available.  */

CONST char *
DEFUN (OS_open_pty_master, (master_fd, master_fname),
       Tchannel * master_fd AND
       CONST char ** master_fname)
{
  static char master_name [24];
  static char slave_name [24];
  int fd;
  PTY_DECLARATIONS;

#ifdef PTY_ITERATION
  PTY_ITERATION
#endif
    {
      PTY_MASTER_NAME_SPRINTF (master_name);
    retry_open:
      fd = (UX_open (master_name, O_RDWR, 0));
      if (fd < 0)
	{
	  if (errno != EINTR)
	    {
#ifdef PTY_ITERATION
	      continue;
#else
	      error_system_call (errno, syscall_open);
#endif
	    }
	  deliver_pending_interrupts ();
	  goto retry_open;
	}
      PTY_SLAVE_NAME_SPRINTF (slave_name, fd);
      MAKE_CHANNEL (fd, channel_type_unix_pty_master, (*master_fd) =);
      (*master_fname) = master_name;
      return (slave_name);
    }
  error_external_return ();
  return (0);
}

void
DEFUN (OS_pty_master_send_signal, (channel, sig), Tchannel channel AND int sig)
{
#ifdef TIOCSIGSEND
  STD_VOID_SYSTEM_CALL
    (syscall_ioctl_TIOCSIGSEND,
     (UX_ioctl ((CHANNEL_DESCRIPTOR (channel)), TIOCSIGSEND, sig)));
#else
#if defined(HAVE_POSIX_SIGNALS) || defined(HAVE_BSD_JOB_CONTROL)
  int gid;
  STD_UINT_SYSTEM_CALL
    (syscall_tcgetpgrp, gid, (UX_tcgetpgrp (CHANNEL_DESCRIPTOR (channel))));
  STD_VOID_SYSTEM_CALL (syscall_kill, (UX_kill ((-gid), sig)));
#else
  error_unimplemented_primitive ();
#endif /* not (HAVE_POSIX_SIGNALS or HAVE_BSD_JOB_CONTROL) */
#endif /* not TIOCSIGSEND */
}

#else /* not HAVE_PTYS */

int
DEFUN_VOID (OS_have_ptys_p)
{
  return (0);
}

CONST char *
DEFUN (OS_open_pty_master, (master_fd, master_fname),
       Tchannel * master_fd AND
       CONST char ** master_fname)
{
  error_unimplemented_primitive ();
}

void
DEFUN (OS_pty_master_send_signal, (channel, sig), Tchannel channel AND int sig)
{
  error_unimplemented_primitive ();
}

#endif /* not HAVE_PTYS */

void
DEFUN (OS_pty_master_kill, (channel), Tchannel channel)
{
  OS_pty_master_send_signal (channel, SIGKILL);
}

void
DEFUN (OS_pty_master_stop, (channel), Tchannel channel)
{
  OS_pty_master_send_signal (channel, SIGTSTP);
}

void
DEFUN (OS_pty_master_continue, (channel), Tchannel channel)
{
  OS_pty_master_send_signal (channel, SIGCONT);
}

void
DEFUN (OS_pty_master_interrupt, (channel), Tchannel channel)
{
  OS_pty_master_send_signal (channel, SIGINT);
}

void
DEFUN (OS_pty_master_quit, (channel), Tchannel channel)
{
  OS_pty_master_send_signal (channel, SIGQUIT);
}

void
DEFUN (OS_pty_master_hangup, (channel), Tchannel channel)
{
  OS_pty_master_send_signal (channel, SIGHUP);
}
