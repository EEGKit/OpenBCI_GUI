
/* This class does nothing, it serves as a signal that the board we are using
 * is null, but does not crash if we use it.
 */
class BoardNull implements Board {

    @Override
    public boolean initialize() {
        return true;
    }

    @Override
    public void uninitialize() {
        // empty
    }

    @Override
    public void update() {
        // empty
    }

    @Override
    public void startStreaming() {
        println("WARNING: calling 'startStreaming' on a NULL board!");
    }

    @Override
    public void stopStreaming() {
        println("WARNING: calling 'stopStreaming' on a NULL board!");
    }

    public boolean isConnected() {
        return false;
    }

    @Override
    public int getSampleRate() {
        return 0;
    }
    
    @Override
    public int getNumEXGChannels() {
        return 0;
    }

    @Override
    public int[] getEXGChannels() {
        return new int[0];
    }

    @Override
    public double[][] getDataThisFrame() {
        return new double[0][0];
    }

    @Override
    public void setChannelActive(int channelIndex, boolean active) {
        // empty
    }

    @Override
    public void sendCommand(String command) {
        // empty
    }

    @Override
    public void setSampleRate(int sampleRate) {
        // empty
    }
};
