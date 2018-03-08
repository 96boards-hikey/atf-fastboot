/*
 * Copyright (c) 2014-2018, Linaro Ltd and Contributors. All rights reserved.
 * Copyright (c) 2014-2018, Hisilicon Ltd and Contributors. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 *
 * Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * Neither the name of ARM nor the names of its contributors may be used
 * to endorse or promote products derived from this software without specific
 * prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <arch_helpers.h>
#include <assert.h>
#include <bl_common.h>
#include <console.h>
#include <ctype.h>
#include <debug.h>
#include <errno.h>
#include <hi6220.h>
#include <mmio.h>
#include <partitions.h>
#include <platform.h>
#include <platform_def.h>
#include <sp804_timer.h>
#include <string.h>
#include "../../bl1/bl1_private.h"
#include "hikey_def.h"
#include "hikey_private.h"

/*******************************************************************************
 * Declarations of linker defined symbols which will help us find the layout
 * of trusted RAM
 ******************************************************************************/
extern unsigned long __COHERENT_RAM_START__;
extern unsigned long __COHERENT_RAM_END__;

/*
 * The next 2 constants identify the extents of the coherent memory region.
 * These addresses are used by the MMU setup code and therefore they must be
 * page-aligned.  It is the responsibility of the linker script to ensure that
 * __COHERENT_RAM_START__ and __COHERENT_RAM_END__ linker symbols refer to
 * page-aligned addresses.
 */
#define BL1_COHERENT_RAM_BASE (unsigned long)(&__COHERENT_RAM_START__)
#define BL1_COHERENT_RAM_LIMIT (unsigned long)(&__COHERENT_RAM_END__)

/* Data structure which holds the extents of the trusted RAM for BL1 */
static meminfo_t bl1_tzram_layout;

meminfo_t *bl1_plat_sec_mem_layout(void)
{
	return &bl1_tzram_layout;
}

/*******************************************************************************
 * Perform any BL1 specific platform actions.
 ******************************************************************************/
void bl1_early_platform_setup(void)
{
	const size_t bl1_size = BL1_RAM_LIMIT - BL1_RAM_BASE;

	/* Initialize the console to provide early debug support */
	console_init(CONSOLE_BASE, PL011_UART_CLK_IN_HZ, PL011_BAUDRATE);

	hi6220_timer_init();

	/* Allow BL1 to see the whole Trusted RAM */
	bl1_tzram_layout.total_base = BL1_RW_BASE;
	bl1_tzram_layout.total_size = BL1_RW_SIZE;

	/* Calculate how much RAM BL1 is using and how much remains free */
	bl1_tzram_layout.free_base = BL1_RW_BASE;
	bl1_tzram_layout.free_size = BL1_RW_SIZE;
	reserve_mem(&bl1_tzram_layout.free_base,
		    &bl1_tzram_layout.free_size,
		    BL1_RAM_BASE,
		    bl1_size);

	INFO("BL1: 0x%lx - 0x%lx [size = %u]\n", BL1_RAM_BASE, BL1_RAM_LIMIT,
	     bl1_size);
}

/*******************************************************************************
 * Perform the very early platform specific architecture setup here. At the
 * moment this only does basic initialization. Later architectural setup
 * (bl1_arch_setup()) does not do anything platform specific.
 ******************************************************************************/
void bl1_plat_arch_setup(void)
{
	configure_mmu_el1(bl1_tzram_layout.total_base,
			  bl1_tzram_layout.total_size,
			  BL1_RO_BASE,
			  BL1_RO_LIMIT,
			  BL1_COHERENT_RAM_BASE,
			  BL1_COHERENT_RAM_LIMIT);
}

static inline char hex2str(unsigned int data)
{
	data &= 0xf;
	if ((data >= 0) && (data <= 9))
		return (char)(data + 0x30);
	return (char)(data - 10 + 0x41);
}

static uint64_t rand(unsigned int data)
{
	int64_t quotient, remainder, t;

	quotient = data / 127773;
	remainder = data % 127773;
	t = 16807 * remainder - 2836 * quotient;
	if (t <= 0)
		t += RANDOM_MAX;
	return (t % ((uint64_t)RANDOM_MAX + 1));
}

int ascii_str_to_unicode_str(char *ascii_str, void *unicode_str)
{
	int i;

	if ((ascii_str == NULL) || (unicode_str == NULL)) {
		return -EINVAL;
	}
	memset(unicode_str, 0, 33);
	for (i = 0; i < 16; i++) {
		*((char *)unicode_str + (i << 1)) = *(ascii_str + i);
	}
	return 0;
}

int unicode_str_to_ascii_str(void *unicode_str, char *ascii_str)
{
	int i;

	if ((ascii_str == NULL) || (unicode_str == NULL)) {
		return -EINVAL;
	}
	for (i = 0; i < 16; i++) {
		*(ascii_str + i) = *((char *)unicode_str + (i << 1));
	}
	*(ascii_str + 16) = '\0';
	return 0;
}

void generate_serialno(struct random_serial_num *random)
{
	unsigned int data, t;
	int i;
	char ascii_sn[17];

	data = mmio_read_32(AO_SC_SYSTEST_SLICER_CNT0);
	t = rand(data);
	random->data = ((uint64_t)t << 32) | data;
	memset(&ascii_sn, 0, 17);
	for (i = 0; i < 8; i++) {
		ascii_sn[i] = hex2str((t >> ((7 - i) << 2)) & 0xf);
	}
	for (i = 0; i < 8; i++) {
		ascii_sn[i + 8] = hex2str((data >> ((7 - i) << 2)) & 0xf);
	}
	ascii_sn[16] = '\0';
	ascii_str_to_unicode_str(ascii_sn, random->serialno);
	random->magic = RANDOM_MAGIC;
}

int assign_serialno(char *cmdbuf, struct random_serial_num *random)
{
	int offset, i;
	char ascii_sn[17];

	offset = 0;
	while (*(cmdbuf + offset) == ' ')
		offset++;
	for (i = 0; i < 16; i++) {
		if (isxdigit(*(cmdbuf + offset + i)))
			continue;
		return -EINVAL;
	}
	memset(&ascii_sn, 0, 17);
	memcpy(&ascii_sn, cmdbuf + offset, 16);
	ascii_str_to_unicode_str(ascii_sn, random->serialno);
	random->magic = RANDOM_MAGIC;
	return 0;
}

static void hikey_verify_serialno(struct random_serial_num *random)
{
	char *serialno;

	serialno = load_serialno();
	if (serialno == NULL) {
		generate_serialno(random);
		flush_random_serialno((unsigned long)&random, sizeof(random));
	}
}

/*******************************************************************************
 * Function which will perform any remaining platform-specific setup that can
 * occur after the MMU and data cache have been enabled.
 ******************************************************************************/
void bl1_platform_setup(void)
{
	struct random_serial_num random;

	hi6220_pll_init();

	io_setup();
	get_partition();
	NOTICE("Enter fastboot mode...\n");
	hikey_verify_serialno(&random);
	usb_download();
}

/*******************************************************************************
 * Before calling this function BL2 is loaded in memory and its entrypoint
 * is set by load_image. This is a placeholder for the platform to change
 * the entrypoint of BL2 and set SPSR and security state.
 * On Juno we are only setting the security state, entrypoint
 ******************************************************************************/
void bl1_plat_set_bl2_ep_info(image_info_t *bl2_image,
			      entry_point_info_t *bl2_ep)
{
	SET_SECURITY_STATE(bl2_ep->h.attr, SECURE);
	bl2_ep->spsr = SPSR_64(MODE_EL1, MODE_SP_ELX, DISABLE_ALL_EXCEPTIONS);
}
