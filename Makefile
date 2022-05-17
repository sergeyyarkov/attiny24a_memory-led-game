MCU = t24
SRCFILE = firmware
TARGET = usbasp
DEVICE = usb

build: $(SRCFILE).asm
	avrasm2 -fI -W+ie $(SRCFILE).asm -l $(SRCFILE).lss

flash:
	avrdude -p $(MCU) -c $(TARGET) -P $(DEVICE) -U flash:w:$(SRCFILE).hex:a

clean:
	rm -f $(SRCFILE).asm~ $(SRCFILE).hex $(SRCFILE).obj $(SRCFILE).lss $(SRCFILE).cof 