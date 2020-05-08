#include "eggnet_core.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <pthread.h>
#include "dma-proxy.h"
#include "dbg.h"


#define DRIVER_KEXT_NAME "dma-proxy.ko"

#define HEIGTH 28
#define WIDTH 28
#define CHANNELS 1
#define IMG_GET(b,h,w,c) image_buffer + c + w*CHANNELS + h*CHANNELS*WIDTH + b *CHANNELS*WIDTH*HEIGTH


static struct dma_proxy_channel_interface *tx_proxy_interface_p;
static int tx_proxy_fd;
static struct dma_proxy_channel_interface *rx_proxy_interface_p;
static int rx_proxy_fd;
static pthread_mutex_t rx_lock;
static pthread_mutex_t tx_lock;

#define LINUX_KERNEL_MODULE_PATH "/lib/modules/4.9.0-xilinx-v2017.4/extra/dma-proxy.ko"
#define LINUX_ADD_KERNEL_MODULE_COMMAND "insmod " LINUX_KERNEL_MODULE_PATH
#define LINUX_DEV_PATH "/dev/dma_proxy_rx"


egg_error_t egg_init_dma()
{

	// Load dma-proxy driver into kernel
	if( access( LINUX_DEV_PATH, F_OK ) == -1 ) {
		CHECK(system(LINUX_ADD_KERNEL_MODULE_COMMAND) == 0,"Error loading dma-proxy kernel module");
	}
	// open dma proxy devices
	tx_proxy_fd = open("/dev/dma_proxy_tx", O_RDWR);
	CHECK(tx_proxy_fd >= 1,"Unable to open dma_proxy_tx device file");

	rx_proxy_fd = open("/dev/dma_proxy_rx", O_RDWR);
	CHECK(rx_proxy_fd >= 1,"Unable to open dma_proxy_rx device file");

	// Map memory with proxy interfaces for tx and rx device
	tx_proxy_interface_p = (struct dma_proxy_channel_interface *)mmap(NULL, sizeof(struct dma_proxy_channel_interface),
											PROT_READ | PROT_WRITE, MAP_SHARED, tx_proxy_fd, 0);
	rx_proxy_interface_p = (struct dma_proxy_channel_interface *)mmap(NULL, sizeof(struct dma_proxy_channel_interface),
									PROT_READ | PROT_WRITE, MAP_SHARED, rx_proxy_fd, 0);

	// initializing read mutex
	CHECK(pthread_mutex_init(&tx_lock, NULL) == 0,"Error initializing read mutex");
	CHECK(pthread_mutex_init(&rx_lock, NULL) == 0,"Error initializing read mutex");

	return EGG_ERROR_NONE;
	error:
		return EGG_ERROR_INIT_FAILDED;

}

egg_error_t egg_close_dma()
{
	// Unmap memory
	CHECK(munmap(tx_proxy_interface_p, sizeof(struct dma_proxy_channel_interface))==0,"Error unmap tx proxy interface");
	CHECK(munmap(rx_proxy_interface_p, sizeof(struct dma_proxy_channel_interface))==0,"Error unmap rx proxy interface");

	// Close devices
	close(tx_proxy_fd);
	close(rx_proxy_fd);
	return EGG_ERROR_NONE;
	error:
		return EGG_ERROR_UDEF;

}

/* The following function is the transmit thread to allow the transmit and the
 * receive channels to be operating simultaneously. The ioctl calls are blocking
 * such that a thread is needed.
 * @param image Pointer to image 1-d array (one row after each other)
 */
egg_error_t egg_tx_img(network_t* network)
{
	int dummy, i;

	/* Set up the length for the DMA transfer and initialize the transmit
 	 * buffer to a known pattern.
 	 */

	// lock the global rx interface
	pthread_mutex_lock(&tx_lock);

	// ToDo: Maybe set this manually to 28x28?
	tx_proxy_interface_p->length = network->layers[1]->width * network->layers[1]->height;

	for (i = 0; i < tx_proxy_interface_p->length; i++)
	{
		tx_proxy_interface_p->buffer[i] = network->img_ptr[i];
	}

	/* Perform the DMA transfer and check the status after it completes
	 * as the call blocks till the transfer is done.
	 */
	ioctl(tx_proxy_fd, 0, &dummy);

	CHECK(tx_proxy_interface_p->status == PROXY_NO_ERROR,"PROXY DMA ERROR. Error sending image");

	pthread_mutex_unlock(&tx_lock);
	return EGG_ERROR_NONE;
	//pthread_exit in calling function

	error:
		pthread_mutex_unlock(&tx_lock);
		return EGG_ERROR_DEVICE_COMMUNICATION_FAILED;
		//pthread_exit in calling function

}


/**
 * The following function is the receive thread to allow to receive.
 * The function is called when the interrupt of the uio device occurs.
 * The ioctl calls are blocking such that a thread is needed.
 * @param network Pointer to a network interface
 * @return Error code, 0 if none
 */
egg_error_t egg_rx_img(network_t* network)
{
	int dummy, i, j;
	pixel_t *img_ptr=0;
	uint32_t intr_count=0;

	wait_for_interrupt(&intr_count);
	// lock the global rx interface
	pthread_mutex_lock(&rx_lock);
	/* Initialize the receive buffer so that it can be verified after the transfer is done
	 * and setup the size of the transfer for the receive channel
	 */
	// Perform one read for each detected interrupt
	for (j=0;j<intr_count;j++)
	{
		for (i = 0; i < OUTPUT_NUMBER; i++)
		{
			rx_proxy_interface_p->buffer[i] = 0;
		}

		rx_proxy_interface_p->length = OUTPUT_NUMBER;

		/* Perform a receive DMA transfer and after it finishes check the status
		 */
		ioctl(rx_proxy_fd, 0, &dummy);

		CHECK(rx_proxy_interface_p->status == PROXY_NO_ERROR,"PROXY DMA ERROR. Error receiving image");

		/* Perform the DMA transfer and check the status after it completes
		 * as the call blocks till the transfer is done.
		 */

		if (network->result_number == 0)
		{
			// allocate pointer to pixel array
			network->results = (pixel_t **) calloc (1, sizeof (pixel_t *));
		}else
		{
			// allocate additional pointer to pixel array
			network->results = (pixel_t **) realloc(network->results, sizeof (pixel_t *)*(network->result_number+1));
		}

		img_ptr = (pixel_t *) calloc (OUTPUT_NUMBER, sizeof (pixel_t));

		for (i = 0; i < OUTPUT_NUMBER; i++)
		{
			img_ptr[i] = rx_proxy_interface_p->buffer[i];
		}
		network->results[network->result_number] = img_ptr;
		network->result_number++;
	}

	pthread_mutex_unlock(&rx_lock);
	return EGG_ERROR_NONE;

	error:
		pthread_mutex_unlock(&rx_lock);
		return EGG_ERROR_DEVICE_COMMUNICATION_FAILED;
		//pthread_exit in calling function

}

