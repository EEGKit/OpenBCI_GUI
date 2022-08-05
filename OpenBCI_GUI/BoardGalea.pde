import brainflow.*;

import org.apache.commons.lang3.ArrayUtils;
import org.apache.commons.lang3.tuple.Pair;

final boolean galeaEnabled = false;

interface GaleaSettingsEnum {
    public String getName();
    public String getCommand();
}

public enum GaleaSR implements GaleaSettingsEnum
{
    SR_250("250Hz", "~6", 250),
    SR_500("500Hz", "~5", 500),
    SR_1000("1000Hz", "~4", 1000);

    private String name;
    private String command;
    private int value;
 
    GaleaSR(String _name, String _command, int _value) {
        this.name = _name;
        this.command = _command;
        this.value = _value;
    }
 
    @Override
    public String getName() {
        return name;
    }

    @Override
    public String getCommand() {
        return command;
    }

    public int getValue() {
        return value;
    }
}

public enum GaleaMode implements GaleaSettingsEnum
{
    DEMO("Demo Mode", "o"),
    DEFAULT("Default Mode", "d"), 
    INTERNAL_SIGNAL("Internal Signal", "f"), 
    EXTERNAL_SIGNAL("External Signal", "g"), 
    PRESET4("All EEG", "h"),
    PRESET5("ALL EMG", "j");

    private String name;
    private String command;
 
    GaleaMode(String _name, String _command) {
        this.name = _name;
        this.command = _command;
    }
 
    @Override
    public String getName() {
        return name;
    }

    @Override
    public String getCommand() {
        return command;
    }
}

class GaleaDefaultSettings extends ADS1299Settings {
    // TODO: modes go here
    GaleaDefaultSettings(Board theBoard, GaleaMode mode) {
        super(theBoard);

        Arrays.fill(values.powerDown, PowerDown.ON);

        switch(mode) {
            case DEMO:
                Arrays.fill(values.gain, 0, 8, Gain.X2);
                Arrays.fill(values.gain, 8, 16, Gain.X4);
                values.gain[9] = Gain.X12;
                values.gain[14] = Gain.X12;

                Arrays.fill(values.inputType, InputType.NORMAL);

                Arrays.fill(values.bias, Bias.NO_INCLUDE);

                Arrays.fill(values.srb2, Srb2.CONNECT);
                values.srb2[8] = Srb2.DISCONNECT;
                values.srb2[10] = Srb2.DISCONNECT;
                values.srb2[11] = Srb2.DISCONNECT;
                values.srb2[12] = Srb2.DISCONNECT;
                values.srb2[13] = Srb2.DISCONNECT;
                values.srb2[15] = Srb2.DISCONNECT;

                Arrays.fill(values.srb1, Srb1.DISCONNECT);

                break;

            case DEFAULT:
                Arrays.fill(values.gain, 0, 8, Gain.X8);
                Arrays.fill(values.gain, 8, 16, Gain.X4);
                values.gain[9] = Gain.X12;
                values.gain[14] = Gain.X12;
                
                Arrays.fill(values.inputType, InputType.NORMAL);

                Arrays.fill(values.bias, Bias.INCLUDE);
                Arrays.fill(values.bias, 8, 16, Bias.NO_INCLUDE);
                values.bias[9] = Bias.INCLUDE;
                values.bias[14] = Bias.INCLUDE;

                Arrays.fill(values.srb2, Srb2.CONNECT);
                Arrays.fill(values.srb2, 8, 16, Srb2.DISCONNECT);
                values.srb2[9] = Srb2.CONNECT;
                values.srb2[14] = Srb2.CONNECT;

                Arrays.fill(values.srb1, Srb1.DISCONNECT);

                break;

            case INTERNAL_SIGNAL:
                Arrays.fill(values.gain, Gain.X1);
                Arrays.fill(values.inputType, InputType.TEST);
                Arrays.fill(values.bias, Bias.NO_INCLUDE);
                Arrays.fill(values.srb2, Srb2.DISCONNECT);
                Arrays.fill(values.srb1, Srb1.DISCONNECT);
                break;

            case EXTERNAL_SIGNAL:
                Arrays.fill(values.gain, Gain.X1);
                Arrays.fill(values.inputType, InputType.NORMAL);
                Arrays.fill(values.bias, Bias.NO_INCLUDE);
                Arrays.fill(values.srb2, Srb2.DISCONNECT);
                Arrays.fill(values.srb1, Srb1.DISCONNECT);
                break;

            case PRESET4:
                // TODO[Galea] This mode is not defined yet
                break;

            case PRESET5:
                // TODO[Galea] This mode is not defined yet
                break;

            default:
                break;
        }
    }
}

class BoardGalea extends BoardBrainFlow
implements ImpedanceSettingsBoard, EDACapableBoard, PPGCapableBoard, BatteryInfoCapableBoard, ADS1299SettingsBoard, AuxDataBoard{

    private final char[] channelSelectForSettings = {'1', '2', '3', '4', '5', '6', '7', '8', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I'};

    protected FixedStack<double[]> accumulatedAuxData = new FixedStack<double[]>();
    protected double[][] auxDataThisFrame;
    protected int auxSamplingRate = -1;
    protected int numAuxChannels = -1;
    protected int auxTimestamp = -1;
    protected double[][] emptyAuxData;

    protected ADS1299Settings currentADS1299Settings;
    protected boolean[] isCheckingImpedance;

    private int[] edaChannelsCache = null;
    private int[] ppgChannelsCache = null;
    private Integer batteryChannelCache = null;

    private BoardIds boardId = BoardIds.GALEA_BOARD;
    private GaleaMode initialSettingsMode;
    private GaleaSR sampleRate;
    private String ipAddress;

    private final GaleaDefaultSettings defaultSettings;
    private boolean useDynamicScaler;

    // needed for playback
    public BoardGalea() {
        super();

        defaultSettings = new GaleaDefaultSettings(this, GaleaMode.DEFAULT);
    }

    public BoardGalea(String _ip, GaleaMode mode, GaleaSR _sampleRate) {
        super();

        isCheckingImpedance = new boolean[getNumEXGChannels()];
        Arrays.fill(isCheckingImpedance, false);

        ipAddress = _ip;
        initialSettingsMode = mode;
        println("Mode command: " + initialSettingsMode.getCommand());
        sampleRate = _sampleRate;
        samplingRateCache = sampleRate.getValue();

        // store a copy of the default settings. This will be used to undo brainflow's
        // gain scaling to re-scale in gui
        defaultSettings = new GaleaDefaultSettings(this, GaleaMode.DEFAULT);
        useDynamicScaler = true;
    }

    @Override
    public boolean initializeInternal() {        
        boolean res = super.initializeInternal();

        if (res) {
            // GaleaDefaultSettings() will send mode command to board
            currentADS1299Settings = new GaleaDefaultSettings(this, initialSettingsMode);
        }
        if (res) {
            // send the mode command to board
            res = sendCommand(initialSettingsMode.getCommand()).getKey().booleanValue();
        }
        if (res) {
            // send the sample rate command to the board
            res = sendCommand(sampleRate.getCommand()).getKey().booleanValue();
        }
        if (res) {
            println("Registers:");
            println(sendCommand("F0").getValue());
        }
        if (res) {
            try {
                auxSamplingRate = BoardShim.get_sampling_rate(getBoardIdInt(), BrainFlowPresets.AUXILIARY_PRESET);
                numAuxChannels = BoardShim.get_num_rows(getBoardIdInt(), BrainFlowPresets.AUXILIARY_PRESET);
                double[] fillAuxData = new double[numAuxChannels];
                accumulatedAuxData.setSize(auxSamplingRate * dataBuff_len_sec);
                accumulatedAuxData.fill(fillAuxData);
            } catch (BrainFlowError e) {
                res = false;
                println("WARNING: could not get info about aux data.");
                e.printStackTrace();
            }
        }

        emptyAuxData = new double[getNumAuxChannels()][0];

        return res;
    }

    // implement mandatory abstract functions
    @Override
    protected BrainFlowInputParams getParams() {
        BrainFlowInputParams params = new BrainFlowInputParams();
        params.ip_address = ipAddress;
        return params;
    }

    @Override
    public BoardIds getBoardId() {
        return boardId;
    }

    @Override
    public void setEXGChannelActive(int channelIndex, boolean active) {
        currentADS1299Settings.setChannelActive(channelIndex, active);
    }
    
    @Override
    public boolean isEXGChannelActive(int channelIndex) {
        return currentADS1299Settings.isChannelActive(channelIndex);
    }
    
    @Override
    public void setCheckingImpedance(int channel, boolean active) {
        char p = '0';
        char n = '0';

        if (active) {
            Srb2 srb2sSetting = currentADS1299Settings.values.srb2[channel];
            if (srb2sSetting == Srb2.CONNECT) {
                n = '1';
            }
            else {
                p = '1';
            }
        }

        // for example: z 4 1 0 Z
        String command = String.format("z%c%c%cZ", channelSelectForSettings[channel], p, n);
        sendCommand(command);

        isCheckingImpedance[channel] = active;
    }

    @Override
    public boolean isCheckingImpedance(int channel) {
        return isCheckingImpedance[channel];
    }

    //Returns the channel number where impedance check is currently active, otherwise return null
    @Override
    public Integer isCheckingImpedanceOnChannel() {
        for (int i = 0; i < isCheckingImpedance.length; i++) {
            if (isCheckingImpedance[i]) {
                return i;
            }
        }
        return null;
    }

    @Override
    protected double[][] getNewDataInternal() {
        double[][] data = super.getNewDataInternal();
        int[] exgChannels = getEXGChannels();
        for (int i = 0; i < exgChannels.length; i++) {
            for (int j = 0; j < data[exgChannels[i]].length; j++) {
                // brainflow assumes default gain. Undo brainflow's scaling and apply new scale.
                double brainflowGain = defaultSettings.values.gain[i].getScalar();
                double currentGain = 1.0;
                if (useDynamicScaler) {
                    currentGain = currentADS1299Settings.values.gain[i].getScalar();
                }
                double scalar = brainflowGain / currentGain;
                data[exgChannels[i]][j] *= scalar;
            }
        }
        return data;
    }

    @Override
    public void updateInternal() {
        // get aux data in updateInternal to dont mess with getNewDataInternal
        if(streaming) {
            try {
                double[][] data = boardShim.get_board_data(BrainFlowPresets.AUXILIARY_PRESET);
                for (int i = 0; i < data[0].length; i++) {
                    double[] newEntry = new double[numAuxChannels];
                    for (int j = 0; j < numAuxChannels; j++) {
                        newEntry[j] = data[j][i];
                    }
                    accumulatedAuxData.push(newEntry);
                }
                auxDataThisFrame = data;
            } catch (BrainFlowError e) {
                println("WARNING: could not get board data.");
                e.printStackTrace();
                auxDataThisFrame = emptyAuxData;
            }
        } else {
            auxDataThisFrame = emptyAuxData;
        }
    }

    @Override
    public ADS1299Settings getADS1299Settings() {
        return currentADS1299Settings;
    }

    @Override
    public char getChannelSelector(int channel) {
        return channelSelectForSettings[channel];
    }

    @Override
    public boolean isPPGActive() {
        return true;
    }

    @Override
    public void setPPGActive(boolean active) {
        outputWarn("PPG is always active for BoardGalea");
    }

    @Override
    public int[] getPPGChannels() {
        if (ppgChannelsCache == null) {
            try {
                ppgChannelsCache = BoardShim.get_ppg_channels(getBoardIdInt(), BrainFlowPresets.AUXILIARY_PRESET);
            } catch (BrainFlowError e) {
                e.printStackTrace();
            }
        }

        return ppgChannelsCache;
    }

    @Override
    public boolean isEDAActive() {
        return true;
    }

    @Override
    public void setEDAActive(boolean active) {
        outputWarn("EDA is always active for BoardGalea");
    }

    @Override
    public int[] getEDAChannels() {
        if (edaChannelsCache == null) {
            try {
                edaChannelsCache = BoardShim.get_eda_channels(getBoardIdInt(), BrainFlowPresets.AUXILIARY_PRESET);
            } catch (BrainFlowError e) {
                e.printStackTrace();
            }
        }

        return edaChannelsCache;
    }

    @Override
    public Integer getBatteryChannel() {
        if (batteryChannelCache == null) {
            try {
                batteryChannelCache = BoardShim.get_battery_channel(getBoardIdInt(), BrainFlowPresets.AUXILIARY_PRESET);
            } catch (BrainFlowError e) {
                e.printStackTrace();
            }
        }

        return batteryChannelCache;
    }

    @Override
    public double getGain(int channel) {
        return getADS1299Settings().values.gain[channel].getScalar();
    }

    @Override
    public boolean getUseDynamicScaler() {
        return useDynamicScaler;
    }

    @Override
    public void setUseDynamicScaler(boolean val) {
        useDynamicScaler = val;
    }
    
    @Override
    protected PacketLossTracker setupPacketLossTracker() {
        final int minSampleIndex = 0;
        final int maxSampleIndex = 255;
        return new PacketLossTracker(getSampleIndexChannel(), getTimestampChannel(),
                                    minSampleIndex, maxSampleIndex);
    }

    @Override
    public String[] getChannelNames() {
        String[] res = super.getChannelNames();
        try {
            if (res.length >= 22) {
                int[] otherChannels = boardShim.get_other_channels(getBoardIdInt());
                res[otherChannels[0]] = "Raw PC Timestamp";
                res[otherChannels[1]] = "Raw Device Timestamp";
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return res;
    }

    @Override
    public void startStreaming() {
        //Check timestamps before start streaming
        controlPanel.fetchSessionNameTextfieldAllBoards();
        if (!streaming) {
            timestampFileName = fetchTimestampFileLocation();
            writeTimestampFile();
        }
        //Start streaming
        super.startStreaming();
    }

    @Override
    public void stopStreaming() {
        super.stopStreaming();
        //Check timestamps immediately after board stops streaming
        //Ignore checking timestamps if GUI has thrown a popup for no data in last X seconds
        if (!streaming && !data_popup_displayed) {
            timestampFileName = fetchTimestampFileLocation();
            writeTimestampFile();
        }
    }

    protected void writeTimestampFile() {
        try {
            File file = new File(timestampFileName);
            file.getParentFile().mkdirs(); // Will create parent directories if not exists
            file.createNewFile();
            FileOutputStream s = new FileOutputStream(file,false);
        } catch (IOException e) {
            println("Failed to create to timestamp file - checkpoint 1");
            e.printStackTrace();
        }
        try {
            FileWriter fw = new FileWriter(timestampFileName, false);
            BufferedWriter bw = new BufferedWriter(fw);
            for (int i = 0; i < 3; i++)
            {
                Pair<Boolean, String> res = sendCommand("calc_time");
                if (res.getKey().booleanValue()) { 
                    bw.write(res.getValue());
                    bw.newLine();
                } else {
                    println("Failed to calc_time");
                    bw.close();
                    return;
                }
            }
            bw.close();
        } catch (IOException e) {
            println("Failed to write to timestamp file - checkpoint 2");
            e.printStackTrace();
        }
    }

    protected String fetchTimestampFileLocation() {
        StringBuilder timestampFileLoc = new StringBuilder();
        timestampFileLoc.append(settings.getSessionPath());
        timestampFileLoc.append("Timestamp_");
        timestampFileLoc.append(directoryManager.getFileNameDateTime());
        timestampFileLoc.append(".txt");
        String result = timestampFileLoc.toString();

        timestampFileLoc.insert(0, "OpenBCI_GUI: Created Galea timestamp file: ");
        println(timestampFileLoc.toString());
        return result;
    }

    public int[] getEEGChannels() {
        if (eegChannelsCache == null) {
            try {
                eegChannelsCache = BoardShim.get_eeg_channels(getBoardIdInt());
            } catch (BrainFlowError e) {
                e.printStackTrace();
            }
        }

        return eegChannelsCache;
    }

    public int[] getEOGChannels() {
        if (eogChannelsCache == null) {
            try {
                eogChannelsCache = BoardShim.get_eog_channels(getBoardIdInt());
            } catch (BrainFlowError e) {
                e.printStackTrace();
            }
        }

        return eogChannelsCache;
    }

    public int[] getEMGChannels() {
        if (emgChannelsCache == null) {
            try {
                emgChannelsCache = BoardShim.get_emg_channels(getBoardIdInt());
            } catch (BrainFlowError e) {
                e.printStackTrace();
            }
        }

        return emgChannelsCache;
    }

    public List<double[]> getAuxData(int maxSamples) {
        int endIndex = accumulatedAuxData.size();
        int startIndex = max(0, endIndex - maxSamples);

        return accumulatedAuxData.subList(startIndex, endIndex);
    }

    @Override
    public List<double[]> getDataWithPPG(int maxSamples) {
        return getAuxData(maxSamples);
    }

    @Override
    public List<double[]> getDataWithBatteryInfo(int maxSamples) {
        return getAuxData(maxSamples);
    }

    @Override
    public List<double[]> getDataWithEDA(int maxSamples) {
        return getAuxData(maxSamples);
    }

    @Override
    protected void addChannelNamesInternal(String[] channelNames) {
        // do nothing here
    }

    @Override
    public int getEDASampleRate() {
        return getAuxSampleRate();
    }

    @Override
    public int getPPGSampleRate() {
        return getAuxSampleRate();
    }

    @Override
    public int getBatteryInfoSampleRate() {
        return getAuxSampleRate();
    }

    public int getAuxSampleRate() {
        if (auxSamplingRate == -1) {
            try {
                auxSamplingRate = BoardShim.get_sampling_rate(getBoardIdInt(), BrainFlowPresets.AUXILIARY_PRESET);
            } catch (BrainFlowError e) {
                e.printStackTrace();
            }
        }

        return auxSamplingRate;
    }

    public int getNumAuxChannels() {
        if (numAuxChannels == -1) {
            try {
                numAuxChannels = BoardShim.get_num_rows(getBoardIdInt(), BrainFlowPresets.AUXILIARY_PRESET);
            } catch (BrainFlowError e) {
                e.printStackTrace();
            }
        }

        return numAuxChannels;
    }

    public int getAuxTimestampChannel() {
        if (auxTimestamp == -1) {
            try {
                auxTimestamp = BoardShim.get_timestamp_channel(getBoardIdInt(), BrainFlowPresets.AUXILIARY_PRESET);
            } catch (BrainFlowError e) {
                e.printStackTrace();
            }
        }

        return auxTimestamp;
    }

    // todo write actual names here
    public String[] getAuxChannelNames() {
        String[] names = new String[getNumAuxChannels()];
        Arrays.fill(names, "Other");
        return names;
    }

    public double[][] getAuxFrameData() {
        return auxDataThisFrame;
    }
};


class BoardGaleaSerial extends BoardGalea {

    public BoardGaleaSerial() {
        super();
    }

    public BoardGaleaSerial(String connectId, GaleaMode mode, GaleaSR _sampleRate) {
        super(connectId, mode, _sampleRate);
    }

    @Override
    public BoardIds getBoardId() {
        return BoardIds.GALEA_SERIAL_BOARD;
    }

    @Override
    protected BrainFlowInputParams getParams() {
        BrainFlowInputParams params = new BrainFlowInputParams();
        params.serial_port = connectId;
        return params;
    }
>>>>>>> data format change (#42)
};
