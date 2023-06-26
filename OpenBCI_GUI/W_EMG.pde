/////////////////////////////////////////////////////////////////////////////////
//
//  Emg_Widget is used to visiualze EMG data by channel, and to trip events
//
//  Created: Colin Fausnaught, December 2016 (with a lot of reworked code from Tao)
//  Modified: Richard Waltman, February 2023
//
//  Custom widget to visiualze EMG data. Features dragable thresholds, serial
//  out communication, channel configuration, digital and analog events.
//
//  KNOWN ISSUES: Cannot resize with window dragging events
//
//  TODO: Add dynamic threshold functionality
////////////////////////////////////////////////////////////////////////////////

class W_emg extends Widget {
    PApplet parent;

    private ControlP5 emgCp5;
    private Button emgSettingsButton;
    private List<controlP5.Controller> cp5ElementsToCheck;

    W_emg (PApplet _parent) {
        super(_parent); //calls the parent CONSTRUCTOR method of Widget (DON'T REMOVE)
        parent = _parent;

        emgCp5 = new ControlP5(ourApplet);
        emgCp5.setGraphics(ourApplet, 0,0);
        emgCp5.setAutoDraw(false);

        createEmgSettingsButton();
        
        cp5ElementsToCheck = new ArrayList<controlP5.Controller>();
        cp5ElementsToCheck.add((controlP5.Controller) emgSettingsButton);
    }

    public void update() {
        super.update(); //calls the parent update() method of Widget (DON'T REMOVE)
        lockElementsOnOverlapCheck(cp5ElementsToCheck);
    }

    public void draw() {
        super.draw(); //calls the parent draw() method of Widget (DON'T REMOVE)

        drawEmgVisualizations();

        emgCp5.draw();
    }

    public void screenResized() {
        super.screenResized(); //calls the parent screenResized() method of Widget (DON'T REMOVE)
        emgCp5.setGraphics(ourApplet, 0, 0);
        emgSettingsButton.setPosition(x0 + 1, y0 + navH + 1);
    }

    private void drawEmgVisualizations() {
        pushStyle();
        noStroke();
        fill(255);
        rect(x, y, w, h);

        float rx = x, ry = y, rw = w, rh = h;
        float scaleFactor = 1.0;
        float scaleFactorJaw = 1.5;
        int rowNum = 4;
        int colNum = currentBoard.getNumEXGChannels() / rowNum;
        float rowOffset = rh / rowNum;
        float colOffset = rw / colNum;
        int index = 0;
        float currentX, currentY;
        

        EmgValues emgValues = dataProcessing.emgValues;

        for (int i = 0; i < rowNum; i++) {
            for (int j = 0; j < colNum; j++) {

                int channel = i * colNum + j;
                int colorIndex = channel % 8;

                pushMatrix();
                currentX = rx + j * colOffset;
                currentY = ry + i * rowOffset; //never name variables on an empty stomach
                translate(currentX, currentY);

                //realtime
                fill(channelColors[colorIndex], 200);
                noStroke();
                circle(2*colOffset/8, rowOffset / 2, scaleFactor * emgValues.averageuV[channel]);

                //circle for outer threshold
                noFill();
                strokeWeight(1);
                stroke(OPENBCI_DARKBLUE, 150);
                circle(2*colOffset/8, rowOffset / 2, scaleFactor * emgValues.upperThreshold[channel]);

                //circle for inner threshold
                stroke(OPENBCI_DARKBLUE, 150);
                circle(2*colOffset/8, rowOffset / 2, scaleFactor * emgValues.lowerThreshold[channel]);

                int _x = int(5*colOffset/8);
                int _y = int(2 * rowOffset / 8);
                int _w = int(5*colOffset/32);
                int _h = int(4*rowOffset/8);

                //draw normalized bar graph of uV w/ matching channel color
                noStroke();
                fill(channelColors[colorIndex], 200);
                rect(_x, 3*_y + 1, _w, map(emgValues.outputNormalized[channel], 0, 1, 0, (-1) * int((4*rowOffset/8))));

                //draw background bar container for mapped uV value indication
                strokeWeight(1);
                stroke(OPENBCI_DARKBLUE, 150);
                noFill();
                rect(_x, _y, _w, _h);

                //draw channel number at upper left corner of row/column cell
                pushStyle();
                stroke(OPENBCI_DARKBLUE);
                fill(OPENBCI_DARKBLUE);
                int _chan = index+1;
                textFont(p5, 12);
                text(_chan + "", 10, 20);
                popStyle();

                index++;
                popMatrix();
            }
        }

        popStyle();
    }

    private void createEmgSettingsButton() {
        emgSettingsButton = createButton(emgCp5, "emgSettingsButton", "EMG Settings", (int) (x0 + 1),
                (int) (y0 + navH + 1), 125, navH - 3, p5, 12, colorNotPressed, OPENBCI_DARKBLUE);
        emgSettingsButton.setBorderColor(OBJECT_BORDER_GREY);
        emgSettingsButton.onRelease(new CallbackListener() {
            public synchronized void controlEvent(CallbackEvent theEvent) {
                if (!emgSettingsPopupIsOpen) {
                    EmgSettingsUI emgSettingsUI = new EmgSettingsUI();
                }
            }
        });
        emgSettingsButton.setDescription("Click to open the EMG Settings UI to adjust how this metric is calculated.");
    }
};
