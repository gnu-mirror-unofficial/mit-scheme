/* -*-C-*-

$Id: dossys.h,v 1.3 1999/01/02 06:11:34 cph Exp $

Copyright (c) 1992, 1999 Massachusetts Institute of Technology

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

#ifndef SCM_DOSSYS_H
#define SCM_DOSSYS_H

#define DOS_SUCCESS	(0)
#define DOS_FAILURE	(-1)
#define dos_boolean	int
#define dos_true	(1)
#define dos_false	(0)

typedef struct version_struct
{
  unsigned char major;
  unsigned char minor;
} version_t;

typedef int handle_t;

/* Console Character I/O */
#ifdef UNUSED
extern int dos_keyboard_input_available_p (void);
extern unsigned char dos_get_keyboard_character (void);
#endif /* UNUSED */
extern int dos_poll_keyboard_character (unsigned char *result);
extern void dos_console_write_character (unsigned char character);
extern int dos_console_write (void * vbuffer, size_t nsize);

/* Handle I/O */
#ifdef UNUSED
extern handle_t dos_open_file_with_handle (unsigned char * name, int mode);
extern int dos_close_file_with_handle (handle_t handle);
extern int dos_read_file_with_handle
	    (handle_t handle, void * buffer, size_t nbytes);
extern int dos_write_file_with_handle
	    (handle_t handle, void * buffer, size_t nbytes);
extern int dos_get_device_status_with_handle (handle_t handle);
extern int dos_set_device_status_with_handle (handle_t handle, int mode);
#endif /* UNUSED */

/* Misc */
extern void dos_get_version (version_t * version_number);
#ifdef UNUSED
extern void dos_reset_drive (void);
extern int dos_set_verify_flag (int verify_p);
#endif /* UNUSED */
extern int dos_set_ctrl_c_check_flag (int check_p);
extern int dos_rename_file (const char *old, const char *new);
#ifdef UNUSED
extern int dos_get_machine_name (char *name);
#endif /* UNUSED */
extern int dos_drive_letter_to_number (char letter);
#ifdef UNUSED
extern char dos_drive_number_to_letter (int number);
extern int dos_get_default_drive (int drive_number);
#endif /* UNUSED */
extern int dos_set_default_drive (int drive_number);
extern int dos_pathname_as_filename (char * name, char * buffer);
extern int dos_split_filename (char * name, char * device, char * filename);

/* Keyboard control */

extern dos_boolean DOS_keyboard_intercepted_p;
extern int dos_restore_kbd_hook (void);
extern int dos_install_kbd_hook (void);
extern unsigned char dos_set_kbd_modifier_mask (unsigned char);

/* DOS Interrupt Vectors */
#define DOS_INTVECT_DIVIDE_BY_0		(0x00)
#define DOS_INTVECT_SINGLE_STEP		(0x01)
#define DOS_INTVECT_NMI			(0x02)
#define DOS_INTVECT_BREAKPOINT		(0x03)
#define DOS_INTVECT_OVERFLOW		(0x04)
#define DOS_INTVECT_PRINT_SCREEN	(0x05)
#define DOS_INTVECT_INVALID_OPCODE	(0x06)
#define DOS_INTVECT_RESERVED_1		(0x07)
#define DOS_INTVECT_SYSTEM_TIMER	(0x08)
#define DOS_INTVECT_KEYBOARD_EVENT	(0x09)
#define DOS_INTVECT_IRQ2		(0x0A)
#define DOS_INTVECT_IRQ3		(0x0B)
#define DOS_INTVECT_IRQ4		(0x0C)
#define DOS_INTVECT_IRQ5		(0x0D)
#define DOS_INTVECT_DISKETTE_EVENT	(0x0E)
#define DOS_INTVECT_IRQ7		(0x0F)
#define DOS_INTVECT_VIDEO		(0x10)
#define DOS_INTVECT_EQUIPMENT		(0x11)
#define DOS_INTVECT_MEMORY_SIZE		(0x12)
#define DOS_INTVECT_DISK_REQUEST	(0x13)
#define DOS_INTVECT_COMMUNICATIONS	(0x14)
#define DOS_INTVECT_SYSTEM_SERVICES	(0x15)
#define DOS_INTVECT_KEYBOARD_REQUEST	(0x16)
#define DOS_INTVECT_PRINTER_REQUEST	(0x17)
#define DOS_INTVECT_IBM_BASIC		(0x18)
#define DOS_INTVECT_BOOTSTRAP		(0x19)
#define DOS_INTVECT_SYSTEM_TIMER_2	(0x1A)
#define DOS_INTVECT_KB_CTRL_BREAK	(0x1B)
#define DOS_INTVECT_USER_TIMER_TICK	(0x1C)
#define DOS_INTVECT_VIDEO_PARAMETERS	(0x1D)
#define DOS_INTVECT_DISKETTE_PARAMETERS	(0x1E)
#define DOS_INTVECT_GRAPHICS_CHARACTERS	(0x1F)
#define DOS_INTVECT_PROGRAM_TERMINATE	(0x20)
#define DOS_INTVECT_DOS_REQUEST		(0x21)
#define DOS_INTVECT_TERMINATE_ADDRESS	(0x22)
#define DOS_INTVECT_DOS_CTRL_BREAK	(0x23)
#define DOS_INTVECT_CRITICAL_ERROR	(0x24)
#define DOS_INTVECT_ABS_DISK_READ	(0x25)
#define DOS_INTVECT_ABS_DISK_WRITE	(0x26)
#define DOS_INTVECT_TSR			(0x27)
#define DOS_INTVECT_DOS_IDLE		(0x28)
#define DOS_INTVECT_DOS_TTY		(0x29)
#define DOS_INTVECT_MS_NET		(0x2A)
#define DOS_INTVECT_DOS_INTERNAL_1	(0x2B)
#define DOS_INTVECT_DOS_INTERNAL_2	(0x2C)
#define DOS_INTVECT_DOS_INTERNAL_3	(0x2D)
#define DOS_INTVECT_BATCH_EXEC		(0x2E)
#define DOS_INTVECT_MULTIPLEX		(0x2F)
#define DOS_INTVECT_CPM_JUMP_1		(0x30)
#define DOS_INTVECT_CPM_JUMP_2		(0x31)
#define DOS_INTVECT_RESERVED_2		(0x32)
#define DOS_INTVECT_MS_MOUSE		(0x33)
/* Non consecutive */
#define DOS_INTVECT_DISKETTE_REQUEST	(0x40)
#define DOS_INTVECT_FIXED_DISK_1_PARAM	(0x41)
#define DOS_INTVECT_EGA_GRAPHICS_CHARS	(0x43)
#define DOS_INTVECT_FIXED_DISK_2_PARAM	(0x46)
#define DOS_INTVECT_USER_ALARM		(0x4A)
#define DOS_INTVECT_PROGRAM_USE_1	(0x60)
#define DOS_INTVECT_PROGRAM_USE_2	(0x61)
#define DOS_INTVECT_PROGRAM_USE_3	(0x62)
#define DOS_INTVECT_PROGRAM_USE_4	(0x63)
#define DOS_INTVECT_PROGRAM_USE_5	(0x64)
#define DOS_INTVECT_PROGRAM_USE_6	(0x65)
#define DOS_INTVECT_PROGRAM_USE_7	(0x66)
#define DOS_INTVECT_EMS_REQUEST		(0x67)
#define DOS_INTVECT_REAL_TIME_CLOCK	(0x70)
#define DOS_INTVECT_IRQ2_REDIRECT	(0x72)
#define DOS_INTVECT_IRQ11		(0x73)
#define DOS_INTVECT_IBM_MOUSE_EVENT	(0x74)
#define DOS_INTVECT_COPROCESSOR_ERROR	(0x75)
#define DOS_INTVECT_HARD_DISK_EVENT	(0x76)
#define DOS_INTVECT_IRQ15		(0x77)

#define MAX_DOS_INTVECT			(0xFF)

#endif /* SCM_DOSSYS_H */
