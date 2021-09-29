MCU = t24
SRCFILE = firmware
TARGET = usbasp
DEVICE = usb

build: $(SRCFILE).asm
	gavrasm $(SRCFILE)

flash:
	avrdude -p $(MCU) -c $(TARGET) -P $(DEVICE) -U flash:w:$(SRCFILE).hex:a
 
clean:
	rm -f $(SRCFILE).asm~ $(SRCFILE).hex $(SRCFILE).obj $(SRCFILE).lst $(SRCFILE).cof