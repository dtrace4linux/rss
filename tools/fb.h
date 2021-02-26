struct imgRawImage {
	unsigned int	numComponents;
	unsigned long	width;
	unsigned long	height;
	unsigned char	*lpData;
	};
struct imgRawImage* loadJpegImageFile(char* lpFilename);
struct imgRawImage* read_png_file(char *lpFilename);

