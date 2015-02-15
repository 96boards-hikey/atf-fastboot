/*
 * Copyright (c) 2014-2015, Linaro Ltd and Contributors. All rights reserved.
 * Copyright (c) 2014-2015, Hisilicon Ltd and Contributors. All rights reserved.
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
#include <cci400.h>
#include <console.h>
#include <debug.h>
#include <errno.h>
#include <gpio.h>
#include <hi6220.h>
#include <mmio.h>
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

static void hikey_gpio_init(void);

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
	console_init(PL011_UART0_BASE, PL011_UART0_CLK_IN_HZ, PL011_BAUDRATE);

	/* Allow BL1 to see the whole Trusted RAM */
	bl1_tzram_layout.total_base = BL1_RW_BASE;
	bl1_tzram_layout.total_size = BL1_RW_SIZE;

	/* Calculate how much RAM BL1 is using and how much remains free */
	bl1_tzram_layout.free_base = BL1_RW_BASE;
	bl1_tzram_layout.free_size = BL1_RW_SIZE;

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
}

/*******************************************************************************
 * Function which will perform any remaining platform-specific setup that can
 * occur after the MMU and data cache have been enabled.
 ******************************************************************************/
void bl1_platform_setup(void)
{
	hikey_gpio_init();
}

static void hikey_gpio_init(void)
{
	gpio_register_device(GPIO0_BASE);
	gpio_register_device(GPIO1_BASE);
	gpio_register_device(GPIO2_BASE);
	gpio_register_device(GPIO3_BASE);
	gpio_register_device(GPIO4_BASE);
	gpio_register_device(GPIO5_BASE);
	gpio_register_device(GPIO6_BASE);
	gpio_register_device(GPIO7_BASE);
	gpio_register_device(GPIO8_BASE);
	gpio_register_device(GPIO9_BASE);
	gpio_register_device(GPIO10_BASE);
	gpio_register_device(GPIO11_BASE);
	gpio_register_device(GPIO12_BASE);
	gpio_register_device(GPIO13_BASE);
	gpio_register_device(GPIO14_BASE);
	gpio_register_device(GPIO15_BASE);
	gpio_register_device(GPIO16_BASE);
	gpio_register_device(GPIO17_BASE);
	gpio_register_device(GPIO18_BASE);
	gpio_register_device(GPIO19_BASE);

	/* Power on indicator LED (User LED0). */
	gpio_direction_output(32);
	gpio_set_value(32, 1);
	gpio_direction_output(33);
	gpio_direction_output(34);
	gpio_direction_output(35);

	hi6220_timer_init();
	hi6220_pll_init();
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
