// https://www.tspi.at/2020/03/20/libjpegexample.html

#include <stdio.h>
#include <malloc.h>
#include <jpeglib.h>
#include <jerror.h>
#include <string.h>
#include "fb.h"

# if 0
enum imageLibraryError filterGrayscale(
	struct imgRawImage* lpInput,
	struct imgRawImage** lpOutput
) {
	unsigned long int i;

	if(lpOutput == NULL) {
		(*lpOutput) = lpInput; /* We will replace our input structure ... */
	} else {
		(*lpOutput) = malloc(sizeof(struct imgRawImage));
		(*lpOutput)->width = lpInput->width;
		(*lpOutput)->height = lpInput->height;
		(*lpOutput)->numComponents = lpInput->numComponents;
		(*lpOutput)->lpData = malloc(sizeof(unsigned char) * lpInput->width*lpInput->height*3);
	}

	for(i = 0; i < lpInput->width*lpInput->height; i=i+1) {
		/* Do a grayscale transformation */
		unsigned char luma = (unsigned char)(
			0.299f * (float)lpInput->lpData[i * 3 + 0]
			+ 0.587f * (float)lpInput->lpData[i * 3 + 1]
			+ 0.114f * (float)lpInput->lpData[i * 3 + 2]
		);
		(*lpOutput)->lpData[i * 3 + 0] = luma;
		(*lpOutput)->lpData[i * 3 + 1] = luma;
		(*lpOutput)->lpData[i * 3 + 2] = luma;
	}

	return imageLibE_Ok;
}
# endif

struct imgRawImage* loadJpegImageFile(char* lpFilename) {
	struct jpeg_decompress_struct info;
	struct jpeg_error_mgr err;

	struct imgRawImage* lpNewImage;

	unsigned long int imgWidth, imgHeight;
	int numComponents;

	unsigned long int dwBufferBytes;
	unsigned char* lpData;

	FILE* fHandle;

	memset(&info, 0, sizeof info);

	fHandle = fopen(lpFilename, "rb");
	if(fHandle == NULL) {
		#ifdef DEBUG
			fprintf(stderr, "%s:%u: Failed to read file %s\n", __FILE__, __LINE__, lpFilename);
		#endif
		return NULL; /* ToDo */
	}

	info.err = jpeg_std_error(&err);
	jpeg_create_decompress(&info);

	jpeg_stdio_src(&info, fHandle);
	if (jpeg_read_header(&info, TRUE) != 1) {
		printf("jpeg: %s - not a valid JPEG file\n", lpFilename);
		return NULL;
	}
	jpeg_start_decompress(&info);
	imgWidth = info.output_width;
	imgHeight = info.output_height;
	numComponents = info.num_components;

	#ifdef DEBUG
		fprintf(
			stderr,
			"%s:%u: Reading JPEG with dimensions %lu x %lu and %u components\n",
			__FILE__, __LINE__,
			imgWidth, imgHeight, numComponents
		);
	#endif

	dwBufferBytes = imgWidth * imgHeight * 3; /* We only read RGB, not A */
	lpData = (unsigned char*)malloc(sizeof(unsigned char)*dwBufferBytes);

	lpNewImage = (struct imgRawImage*)malloc(sizeof(struct imgRawImage));
	lpNewImage->numComponents = numComponents;
	lpNewImage->width = imgWidth;
	lpNewImage->height = imgHeight;
	lpNewImage->lpData = lpData;

	int stride = info.output_width * info.output_components;

	/* Read scanline by scanline */
	unsigned char *ptr = lpData;
	while(info.output_scanline < info.output_height) {
		unsigned char* buf[1];
		buf[0] = ptr;
		jpeg_read_scanlines(&info, buf, 1);
		ptr += stride;
	}

	jpeg_finish_decompress(&info);
	jpeg_destroy_decompress(&info);
	fclose(fHandle);

	return lpNewImage;
}