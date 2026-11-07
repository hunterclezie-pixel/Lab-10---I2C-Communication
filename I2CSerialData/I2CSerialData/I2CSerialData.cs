using System.Globalization;
using System.IO.Ports;
using System.Text;
using System.Text.Json;

namespace I2CSerialData
{
    public partial class I2CSerialData : Form
    {
        public I2CSerialData()
        {
            InitializeComponent();

            // Setup ComboBoxes --------------------------------------------------------
            OperationComboBox.Items.Clear();
            OperationComboBox.Items.Add("Identify");
            OperationComboBox.Items.Add("Probe");
            OperationComboBox.Items.Add("Write");
            OperationComboBox.Items.Add("Read");
            OperationComboBox.Items.Add("Raw Frame");
            OperationComboBox.SelectedIndex = 0;

            DataModeComboBox.Items.Clear();
            DataModeComboBox.Items.Add("Hex");
            DataModeComboBox.Items.Add("Text");
            DataModeComboBox.SelectedIndex = 0;

            // Save the log and presets outside the build folder.
            string folder = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
                "RCET3375_Lab10");
            Directory.CreateDirectory(folder);
            logFile = Path.Combine(folder, "I2CBridgeLog.txt");
            savedFile = Path.Combine(folder, "SavedCommands.json");

            // Event handlers --------------------------------------------------------
            StatusTimer.Interval = 20;
            StatusTimer.Tick -= StatusTimer_Tick;
            StatusTimer.Tick += StatusTimer_Tick;
            FormClosing -= SerialData_FormClosing;
            FormClosing += SerialData_FormClosing;

            SaveCommandButton.Click += SaveCommandButton_Click;
            LoadCommandButton.Click += LoadCommandButton_Click;
            DeleteCommandButton.Click += DeleteCommandButton_Click;
            SendSavedButton.Click += SendSavedButton_Click;
            ExitButton.Click -= ExitButton_Click;
            ExitButton.Click += ExitButton_Click;

            OperationComboBox.SelectedIndexChanged += PreviewChanged;
            DataModeComboBox.SelectedIndexChanged += PreviewChanged;
            AddressTextBox.TextChanged += PreviewChanged;
            ReadCountTextBox.TextChanged += PreviewChanged;
            OutputTextBox.TextChanged += PreviewChanged;
            RawFrameTextBox.TextChanged += PreviewChanged;

            LoadSavedCommands();
            UpdatePreview();
            Info("Log file: " + logFile);
            StatusTimer.Start();
        }

        // Global Variables below here ------------------------------------------------
        static readonly byte[] IdRequest = { 0x24, 0x49, 0x00 };
        static readonly byte[] IdReply = { 0x24, 0x49, 0x02, 0x33, 0x75 };

        SerialPort serialPort = new SerialPort();
        byte[] rxBuffer = new byte[260];
        int rxCount = 0;

        bool verified = false;
        bool waiting = false;
        bool searching = false;
        bool scanningAddresses = false;
        bool waitingForScan = false;
        bool waitingForHeartbeat = false;
        volatile bool closing = false;

        byte expectedReply = 0;
        byte currentScanAddress = 0;
        byte currentReadAddress = 0;
        int expectedReadCount = -1;
        int scanIndex = 0;
        string currentRequest = "";
        byte[] currentPacket = Array.Empty<byte>();

        DateTime deadline;
        DateTime nextSearch = DateTime.MinValue;
        DateTime nextHeartbeat = DateTime.MinValue;
        DateTime nextPortCheck = DateTime.MinValue;
        DateTime nextAllowedRequest = DateTime.MinValue;

        string logFile = "";
        string savedFile = "";
        bool logWarningShown = false;
        List<SavedCommand> savedCommands = new List<SavedCommand>();
        Dictionary<byte, byte> selectedPointers = new Dictionary<byte, byte>();

        public class SavedCommand
        {
            public string Name { get; set; } = "";
            public string Operation { get; set; } = "";
            public string Address { get; set; } = "";
            public string ReadCount { get; set; } = "";
            public string Data { get; set; } = "";
            public string DataMode { get; set; } = "";
            public string RawFrame { get; set; } = "";
        }

        // Custom Methods below here --------------------------------------------------

        // Add all UART traffic, errors, and connection changes to the screen and file.
        void AddToList(string direction, byte[] data, int count, string note, string port = null, DateTime? time = null)
        {
            if (port == null)
                port = serialPort.IsOpen ? serialPort.PortName : "none";

            string hex = count > 0 ? BitConverter.ToString(data, 0, count).Replace("-", " ") : "";
            string line = (time ?? DateTime.Now).ToString("yyyy-MM-dd HH:mm:ss.fff") +
                          " | " + port + " | " + direction + " | LEN=" + count +
                          " | " + hex + " | " + note;

            ComListBox.Items.Add(line);
            ComListBox.TopIndex = ComListBox.Items.Count - 1;

            try
            {
                File.AppendAllText(logFile, line + Environment.NewLine);
            }
            catch (Exception ex)
            {
                if (!logWarningShown)
                {
                    logWarningShown = true;
                    MessageBox.Show("Could not write log file: " + ex.Message);
                }
            }
        }

        void Info(string note)
        {
            AddToList("INFO", Array.Empty<byte>(), 0, note);
        }

        void Error(string note)
        {
            AddToList("ERROR", Array.Empty<byte>(), 0, note);
        }

        // Port discovery runs in a background task; return its logs to the form thread.
        void LogSearch(string direction, byte[] data, int count, string note, string port)
        {
            DateTime time = DateTime.Now;
            if (closing || !IsHandleCreated) return;

            try
            {
                BeginInvoke(new Action(() =>
                {
                    if (!closing) AddToList(direction, data, count, note, port, time);
                }));
            }
            catch (InvalidOperationException) { }
        }

        string Hex(byte[] data)
        {
            return BitConverter.ToString(data).Replace("-", " ");
        }

        // Turn a space-separated hexadecimal string into actual bytes.
        bool TryHexBytes(string text, out byte[] bytes)
        {
            bytes = Array.Empty<byte>();
            string[] parts = text.Split(new char[] { ' ', ',', '\t', '\r', '\n', '-' },
                                         StringSplitOptions.RemoveEmptyEntries);
            List<byte> result = new List<byte>();

            for (int i = 0; i < parts.Length; i++)
            {
                byte value;
                if (parts[i].Length != 2 ||
                    !byte.TryParse(parts[i], NumberStyles.HexNumber,
                                   CultureInfo.InvariantCulture, out value))
                    return false;

                result.Add(value);
            }

            bytes = result.ToArray();
            return true;
        }

        bool TryAddress(out byte address)
        {
            string value = AddressTextBox.Text.Trim();
            if (value.StartsWith("0x", StringComparison.OrdinalIgnoreCase))
                value = value.Substring(2);

            return byte.TryParse(value, NumberStyles.HexNumber,
                                 CultureInfo.InvariantCulture, out address);
        }

        // Build the exact binary UART packet from the selected controls.
        bool BuildPacket(out byte[] packet, out string problem)
        {
            packet = Array.Empty<byte>();
            problem = "";
            string operation = OperationComboBox.Text;

            if (operation == "Raw Frame")
            {
                if (!TryHexBytes(RawFrameTextBox.Text, out packet) || packet.Length == 0)
                {
                    problem = "Enter raw hex bytes, such as 24 50 01 20.";
                    return false;
                }
                return true;
            }

            if (operation == "Identify")
            {
                packet = (byte[])IdRequest.Clone();
                return true;
            }

            byte address;
            if (!TryAddress(out address))
            {
                problem = "Enter an I2C address in hex (00 through FF).";
                return false;
            }

            if (operation == "Probe")
            {
                packet = new byte[] { 0x24, 0x50, 0x01, address };
                return true;
            }

            if (operation == "Read")
            {
                byte count;
                if (!byte.TryParse(ReadCountTextBox.Text.Trim(), out count))
                {
                    problem = "Read count must be a decimal byte (0 through 255).";
                    return false;
                }
                packet = new byte[] { 0x24, 0x52, 0x02, address, count };
                return true;
            }

            if (operation == "Write")
            {
                byte[] data;
                if (DataModeComboBox.Text == "Hex")
                {
                    if (!TryHexBytes(OutputTextBox.Text, out data))
                    {
                        problem = "Enter two-digit hex bytes like 01 41.";
                        return false;
                    }
                }
                else
                {
                    data = Encoding.UTF8.GetBytes(OutputTextBox.Text);
                }

                if (data.Length > 254)
                {
                    problem = "The UART length field holds only one byte (0-255).";
                    return false;
                }

                packet = new byte[data.Length + 4];
                packet[0] = 0x24;
                packet[1] = 0x57;
                packet[2] = (byte)(data.Length + 1);
                packet[3] = address;
                Array.Copy(data, 0, packet, 4, data.Length);
                return true;
            }

            problem = "Choose a valid operation.";
            return false;
        }

        string DescribeRequest(byte[] packet)
        {
            if (packet.Length < 3 || packet[0] != 0x24) return "Raw UART data";
            if (packet[1] == 0x49) return "Bridge identity request";
            if (packet.Length < 4) return "UART command 0x" + packet[1].ToString("X2");

            string address = "0x" + packet[3].ToString("X2");
            if (packet[1] == 0x50) return "I2C probe " + address;
            if (packet[1] == 0x57) return "I2C write " + address +
                                        ", data bytes " + Math.Max(0, packet.Length - 4);
            if (packet[1] == 0x52 && packet.Length >= 5)
                return "I2C read " + address + ", count " + packet[4];
            return "UART command 0x" + packet[1].ToString("X2");
        }

        string PacketWarning(byte[] packet)
        {
            if (packet.Length < 3) return "WARNING: Missing UART frame bytes.";
            if (packet[0] != 0x24) return "WARNING: Frame does not start with 24.";
            if (packet[2] != packet.Length - 3) return "WARNING: Declared length does not match actual bytes.";
            if (packet[2] > 24) return "WARNING: Payload exceeds bridge limit of 24 bytes.";

            if (packet[1] == 0x49 && packet[2] != 0)
                return "WARNING: Identify should have no payload.";

            if (packet[1] == 0x50 && packet[2] != 1)
                return "WARNING: Probe should have exactly one address byte.";

            if (packet[1] == 0x52 && packet[2] != 2)
                return "WARNING: Read should have address and count bytes.";

            if (packet[1] == 0x57 && (packet[2] < 2 || packet[2] > 24))
                return "WARNING: Write needs an address and 1-23 data bytes.";

            if (packet[1] == 0x52 && packet.Length >= 5 &&
                (packet[4] == 0 || packet[4] > 23))
                return "WARNING: Read count must be 1-23 for a valid request.";

            if ((packet[1] == 0x50 || packet[1] == 0x52 || packet[1] == 0x57) &&
                packet.Length >= 4 &&
                (packet[3] < 0x08 || packet[3] > 0x77))
                return "WARNING: Address is reserved or outside ordinary I2C range.";

            return "";
        }

        void UpdatePreview()
        {
            byte[] packet;
            string problem;
            if (!BuildPacket(out packet, out problem))
            {
                PacketPreviewTextBox.Text = problem;
                return;
            }

            string warning = PacketWarning(packet);
            PacketPreviewTextBox.Text = "UART bytes: " + Hex(packet) +
                Environment.NewLine + "Total bytes: " + packet.Length +
                " | Declared payload: " + (packet.Length >= 3 ? packet[2].ToString() : "n/a") +
                " | Actual payload: " + Math.Max(0, packet.Length - 3) +
                (warning.Length > 0 ? Environment.NewLine + warning : "");
        }

        // Only one request is outstanding, including scans and identity checks.
        void SendPacket(byte[] packet, string note, bool scan = false, bool heartbeat = false)
        {
            if (!verified || !serialPort.IsOpen || waiting) return;
            if (DateTime.Now < nextAllowedRequest) return;

            try
            {
                waiting = true;
                waitingForScan = scan;
                waitingForHeartbeat = heartbeat;
                expectedReply = packet.Length > 1 ? packet[1] : (byte)0;
                expectedReadCount = expectedReply == 0x52 && packet.Length >= 5 ? packet[4] : -1;
                currentReadAddress = packet.Length >= 4 ? packet[3] : (byte)0;
                currentRequest = note;
                currentPacket = (byte[])packet.Clone();
                deadline = DateTime.Now.AddMilliseconds(1500);
                rxCount = 0;

                serialPort.Write(packet, 0, packet.Length);
                AddToList("TX", packet, packet.Length, note);
            }
            catch (Exception ex)
            {
                Error("Send failed for " + note + ": " + ex.Message);
                LostConnection("Serial write failed");
            }
        }

        string DecodeReply(byte[] reply)
        {
            if (reply.Length < 3) return "Malformed UART reply";
            byte command = reply[1];
            int length = reply[2];

            if (command == 0x49)
                return Hex(reply) == Hex(IdReply) ? "Bridge ID = 0x3375" : "Unexpected bridge identity";

            if (command == 0x50)
                return length == 1 && reply[3] == 0 ? "I2C probe ACK" : "Invalid probe reply";

            if (command == 0x57)
                return length == 1 && reply[3] == 0 ? "I2C write successful" : "Invalid write reply";

            if (command == 0x52)
            {
                if (length < 2 || reply[3] != 0) return "Invalid read reply";
                byte[] data = new byte[length - 1];
                Array.Copy(reply, 4, data, 0, data.Length);
                string result = "I2C read successful: " + Hex(data);

                byte pointer;
                if (currentReadAddress == 0x20 && selectedPointers.TryGetValue(0x20, out pointer))
                {
                    if (pointer == 0x00 && data.Length == 1)
                        result += " | PORTB switches = 0x" + (data[0] & 0x3F).ToString("X2");
                    if (pointer == 0x02 && data.Length == 2)
                    {
                        int adc = ((data[0] & 0x03) << 8) | data[1];
                        result += " | PIC AN2 ADC = " + adc;
                    }
                }
                return result;
            }

            if (command == 0x45)
            {
                if (length != 2) return "Malformed error packet";
                byte category = reply[3];
                byte detail = reply[4];

                if (category == 0x01) return "UART FRAMING ERROR, detail 0x" + detail.ToString("X2");
                if (category == 0x02) return "UART OVERRUN ERROR, detail 0x" + detail.ToString("X2");
                if (category == 0x04)
                {
                    if (detail == 0x01) return "I2C NACK (address or data)";
                    if (detail == 0x02) return "I2C TIMEOUT";
                    if (detail == 0x03) return "I2C BUS LOW / not idle";
                    if (detail == 0x04) return "I2C SCL HELD LOW";
                    return "Unknown I2C error: 0x" + detail.ToString("X2");
                }
                if (category == 0x05)
                {
                    if (detail == 0x01) return "BRIDGE ERROR: invalid length or count";
                    if (detail == 0x02) return "BRIDGE ERROR: unknown command";
                    if (detail == 0x03) return "BRIDGE ERROR: invalid I2C address";
                    return "Unknown bridge error: 0x" + detail.ToString("X2");
                }
                return "Unknown error category: 0x" + category.ToString("X2");
            }

            return "Unexpected UART command: 0x" + command.ToString("X2");
        }

        // Collect reply bytes even if Windows delivers them in separate serial reads.
        void ReceiveByte(byte value)
        {
            if (rxCount == 0 && value != 0x24)
            {
                AddToList("ERROR", new byte[] { value }, 1, "Unexpected byte outside frame");
                return;
            }

            rxBuffer[rxCount] = value;
            rxCount++;

            if (rxCount == 3 && rxBuffer[2] > 24)
            {
                AddToList("ERROR", rxBuffer, rxCount, "Malformed reply: length exceeds 24");
                rxCount = 0;
                if (waiting) FinishRequest(false, false, "Malformed reply length");
                return;
            }

            if (rxCount < 3) return;
            if (rxCount < rxBuffer[2] + 3) return;

            byte[] reply = new byte[rxCount];
            Array.Copy(rxBuffer, reply, rxCount);
            rxCount = 0;

            string meaning = DecodeReply(reply);
            AddToList("RX", reply, reply.Length, meaning);

            if (!waiting)
            {
                Error("Unsolicited UART reply: " + Hex(reply));
                return;
            }

            if (reply[1] == 0x45)
            {
                bool nack = reply.Length == 5 && reply[3] == 0x04 && reply[4] == 0x01;
                FinishRequest(false, nack, meaning);
                return;
            }

            if (reply[1] != expectedReply)
            {
                FinishRequest(false, false, "Wrong reply command: " + meaning);
                return;
            }

            bool valid = false;
            if (expectedReply == 0x49)
                valid = reply.Length == IdReply.Length && Hex(reply) == Hex(IdReply);
            else if (expectedReply == 0x50 || expectedReply == 0x57)
                valid = reply.Length == 4 && reply[2] == 1 && reply[3] == 0;
            else if (expectedReply == 0x52)
                valid = expectedReadCount >= 1 && reply[2] == expectedReadCount + 1 &&
                        reply[3] == 0;

            // Remember a selected register pointer only after a successful write.
            if (valid && expectedReply == 0x57 && currentPacket.Length >= 5)
                selectedPointers[currentPacket[3]] = currentPacket[4];

            FinishRequest(valid, false, valid ? meaning : "Malformed or mismatched reply");
        }

        void FinishRequest(bool success, bool nack, string result)
        {
            bool wasScan = waitingForScan;
            bool wasHeartbeat = waitingForHeartbeat;
            string request = currentRequest;

            waiting = false;
            waitingForScan = false;
            waitingForHeartbeat = false;
            expectedReply = 0;
            expectedReadCount = -1;
            currentRequest = "";

            if (!success)
                Error(request + " failed: " + result);

            if (wasScan)
            {
                string state = success ? "ACK" : nack ? "NACK" : "Communication error: " + result;
                ScanResultsListBox.Items.Add(currentScanAddress.ToString("X2") + " - " + state);
                if (success) FoundAddressesListBox.Items.Add("0x" + currentScanAddress.ToString("X2"));
                scanIndex++;
                UpdateScanProgress();
            }

            if (wasHeartbeat && !success)
                LostConnection("Identity heartbeat failed: " + result);
        }

        void RequestTimedOut()
        {
            if (rxCount > 0)
                AddToList("ERROR", rxBuffer, rxCount, "Incomplete reply for " + currentRequest);
            rxCount = 0;
            try { serialPort.DiscardInBuffer(); } catch (Exception) { }
            nextAllowedRequest = DateTime.Now.AddMilliseconds(250);
            FinishRequest(false, false, "Reply timeout (1500 ms)");
        }

        // A scan examines all 128 values but never probes the 16 reserved values.
        void ScanNextAddress()
        {
            while (scanIndex < 128 &&
                   (scanIndex < 0x08 || scanIndex > 0x77))
            {
                ScanResultsListBox.Items.Add(scanIndex.ToString("X2") + " - Reserved");
                scanIndex++;
                UpdateScanProgress();
            }

            if (scanIndex >= 128)
            {
                scanningAddresses = false;
                ScanButton.Text = "Scan";
                Info("Address scan complete; ACK devices: " + FoundAddressesListBox.Items.Count);
                return;
            }

            currentScanAddress = (byte)scanIndex;
            byte[] probe = { 0x24, 0x50, 0x01, currentScanAddress };
            SendPacket(probe, "Scan address 0x" + currentScanAddress.ToString("X2"), true);
        }

        void UpdateScanProgress()
        {
            ScanStatusLabel.Text = scanIndex + "/128 checked, " + FoundAddressesListBox.Items.Count + " ACK";
        }

        // Verify the identity before accepting any serial port.
        SerialPort TryPort(string name)
        {
            SerialPort port = null;
            bool accepted = false;

            try
            {
                port = new SerialPort(name, 9600, Parity.None, 8, StopBits.One);
                port.ReadTimeout = 50;
                port.WriteTimeout = 500;
                port.Open();
                Thread.Sleep(100);

                for (int attempt = 0; attempt < 2 && !closing && !accepted; attempt++)
                {
                    port.DiscardInBuffer();
                    port.Write(IdRequest, 0, IdRequest.Length);
                    LogSearch("TX", IdRequest, IdRequest.Length, "Auto identity request", name);

                    List<byte> reply = new List<byte>();
                    DateTime end = DateTime.UtcNow.AddMilliseconds(600);
                    while (DateTime.UtcNow < end && reply.Count < 5 && !closing)
                    {
                        try { reply.Add((byte)port.ReadByte()); }
                        catch (TimeoutException) { }
                    }
                    Thread.Sleep(25);
                    while (port.BytesToRead > 0 && reply.Count < 32)
                        reply.Add((byte)port.ReadByte());

                    byte[] data = reply.ToArray();
                    if (data.Length > 0)
                        LogSearch("RX", data, data.Length, "Identity discovery response", name);
                    else
                        LogSearch("ERROR", data, 0, "Identity discovery timeout", name);

                    accepted = data.Length == IdReply.Length && Hex(data) == Hex(IdReply);
                }
            }
            catch (Exception ex)
            {
                LogSearch("ERROR", Array.Empty<byte>(), 0, "Port check failed: " + ex.Message, name);
            }

            if (!accepted && port != null)
            {
                try { port.Close(); port.Dispose(); } catch (Exception) { }
            }
            return accepted ? port : null;
        }

        SerialPort FindPIC()
        {
            string[] ports;
            try { ports = SerialPort.GetPortNames(); }
            catch (Exception ex)
            {
                LogSearch("ERROR", Array.Empty<byte>(), 0, "Port list failed: " + ex.Message, "none");
                return null;
            }

            foreach (string name in ports)
            {
                if (closing) return null;
                SerialPort found = TryPort(name);
                if (found != null) return found;
            }
            return null;
        }

        async void StartDiscovery()
        {
            if (searching || verified || closing) return;
            searching = true;
            SerialPort found = null;

            try { found = await Task.Run(FindPIC); }
            catch (Exception ex) { Error("Port discovery failed: " + ex.Message); }
            searching = false;

            if (closing)
            {
                if (found != null) found.Dispose();
                return;
            }

            if (found == null)
            {
                StatusLabel.Text = "Disconnected - searching...";
                nextSearch = DateTime.Now.AddSeconds(1);
                return;
            }

            try { serialPort.Close(); serialPort.Dispose(); } catch (Exception) { }
            serialPort = found;
            verified = true;
            waiting = false;
            rxCount = 0;
            nextAllowedRequest = DateTime.MinValue;
            nextHeartbeat = DateTime.Now.AddSeconds(1);
            nextPortCheck = DateTime.Now.AddSeconds(1);

            PortsComboBox.Items.Clear();
            PortsComboBox.Items.Add(found.PortName);
            PortsComboBox.SelectedIndex = 0;
            StatusLabel.Text = "Connected: " + found.PortName;
            Info("Verified bridge connected at " + found.PortName);
        }

        void LostConnection(string reason)
        {
            string name = serialPort.PortName;
            Error("Disconnected from " + name + ": " + reason +
                  (currentRequest.Length > 0 ? " | Failed request: " + currentRequest : ""));

            try { serialPort.Close(); serialPort.Dispose(); } catch (Exception) { }
            serialPort = new SerialPort();
            verified = false;
            waiting = false;
            waitingForScan = false;
            waitingForHeartbeat = false;
            rxCount = 0;
            currentRequest = "";
            scanningAddresses = false;
            ScanButton.Text = "Scan";
            StatusLabel.Text = "Disconnected - searching...";
            PortsComboBox.Items.Clear();
            nextSearch = DateTime.Now.AddSeconds(1);
        }

        // Save and restore named transmissions between program runs.
        void LoadSavedCommands()
        {
            try
            {
                if (File.Exists(savedFile))
                    savedCommands = JsonSerializer.Deserialize<List<SavedCommand>>(
                        File.ReadAllText(savedFile)) ?? new List<SavedCommand>();
            }
            catch (Exception ex) { Error("Could not load saved commands: " + ex.Message); }
            RefreshSavedList();
        }

        void SaveSavedCommands()
        {
            try
            {
                File.WriteAllText(savedFile,
                    JsonSerializer.Serialize(savedCommands, new JsonSerializerOptions { WriteIndented = true }));
            }
            catch (Exception ex) { Error("Could not save commands: " + ex.Message); }
        }

        void RefreshSavedList()
        {
            SavedCommandsComboBox.Items.Clear();
            foreach (SavedCommand item in savedCommands)
                SavedCommandsComboBox.Items.Add(item.Name);
        }

        void LoadSelectedCommand()
        {
            int index = SavedCommandsComboBox.SelectedIndex;
            if (index < 0 || index >= savedCommands.Count) return;

            SavedCommand item = savedCommands[index];
            SavedNameTextBox.Text = item.Name;
            OperationComboBox.Text = item.Operation;
            AddressTextBox.Text = item.Address;
            ReadCountTextBox.Text = item.ReadCount;
            OutputTextBox.Text = item.Data;
            DataModeComboBox.Text = item.DataMode;
            RawFrameTextBox.Text = item.RawFrame;
            UpdatePreview();
        }

        void UpdateButtons()
        {
            bool ready = verified && serialPort.IsOpen && !waiting && !scanningAddresses &&
                         DateTime.Now >= nextAllowedRequest;
            SendButton.Enabled = ready;
            SendSavedButton.Enabled = ready;
            ScanButton.Enabled = verified;
        }

        // Event Handlers below here ---------------------------------------------------

        private void PreviewChanged(object sender, EventArgs e)
        {
            UpdatePreview();
        }

        private void SendButton_Click(object sender, EventArgs e)
        {
            if (!verified || waiting || scanningAddresses || !serialPort.IsOpen)
            {
                Error("Cannot send while disconnected or another request is active.");
                return;
            }

            byte[] packet;
            string problem;
            if (!BuildPacket(out packet, out problem))
            {
                Error("GUI input error: " + problem);
                MessageBox.Show(problem);
                return;
            }

            string warning = PacketWarning(packet);
            if (warning.Length > 0)
                Info("Boundary test warning: " + warning);

            SendPacket(packet, "Manual " + DescribeRequest(packet) +
                               (warning.Length > 0 ? " (boundary test)" : ""));
            UpdateButtons();
        }

        private void SaveCommandButton_Click(object sender, EventArgs e)
        {
            string name = SavedNameTextBox.Text.Trim();
            if (name.Length == 0)
            {
                MessageBox.Show("Enter a name for this command.");
                return;
            }

            byte[] packet;
            string problem;
            if (!BuildPacket(out packet, out problem))
            {
                Error("Cannot save invalid input: " + problem);
                MessageBox.Show(problem);
                return;
            }

            SavedCommand item = new SavedCommand();
            item.Name = name;
            item.Operation = OperationComboBox.Text;
            item.Address = AddressTextBox.Text;
            item.ReadCount = ReadCountTextBox.Text;
            item.Data = OutputTextBox.Text;
            item.DataMode = DataModeComboBox.Text;
            item.RawFrame = RawFrameTextBox.Text;

            int existing = savedCommands.FindIndex(x =>
                string.Equals(x.Name, name, StringComparison.OrdinalIgnoreCase));
            if (existing >= 0) savedCommands[existing] = item;
            else savedCommands.Add(item);

            SaveSavedCommands();
            RefreshSavedList();
            SavedCommandsComboBox.SelectedItem = name;
            Info("Saved command: " + name);
        }

        private void LoadCommandButton_Click(object sender, EventArgs e)
        {
            LoadSelectedCommand();
        }

        private void DeleteCommandButton_Click(object sender, EventArgs e)
        {
            int index = SavedCommandsComboBox.SelectedIndex;
            if (index < 0 || index >= savedCommands.Count) return;
            string name = savedCommands[index].Name;
            savedCommands.RemoveAt(index);
            SaveSavedCommands();
            RefreshSavedList();
            Info("Deleted saved command: " + name);
        }

        private void SendSavedButton_Click(object sender, EventArgs e)
        {
            LoadSelectedCommand();
            if (SavedCommandsComboBox.SelectedIndex >= 0)
                SendButton_Click(sender, e);
        }

        private void ExitButton_Click(object sender, EventArgs e)
        {
            Close();
        }

        private void SerialData_FormClosing(object sender, FormClosingEventArgs e)
        {
            closing = true;
            StatusTimer.Stop();
            try { serialPort.Close(); serialPort.Dispose(); } catch (Exception) { }
        }

        private void StatusTimer_Tick(object sender, EventArgs e)
        {
            if (closing) return;

            // Search for the PIC if disconnected
            if (!verified)
            {
                if (!searching && DateTime.Now >= nextSearch)
                {
                    StartDiscovery();
                }

                UpdateButtons();
                return;
            }

            try
            {
                // Check if the serial port is still open
                if (!serialPort.IsOpen)
                {
                    LostConnection("Serial port closed");
                    return;
                }

                // Check if the COM port is still available
                if (DateTime.Now >= nextPortCheck)
                {
                    nextPortCheck = DateTime.Now.AddSeconds(1);

                    if (Array.IndexOf(SerialPort.GetPortNames(), serialPort.PortName) == -1)
                    {
                        LostConnection("COM port disappeared");
                        return;
                    }
                }

                // Read incoming UART data
                while (verified && serialPort.BytesToRead > 0)
                {
                    ReceiveByte((byte)serialPort.ReadByte());
                }

                if (!verified) return;

                // Check if a request has timed out
                if (waiting && DateTime.Now > deadline)
                {
                    RequestTimedOut();
                }

                if (!verified) return;

                // Continue scanning the I2C bus automatically
                if (scanningAddresses && !waiting)
                {
                    if (DateTime.Now >= nextAllowedRequest)
                    {
                        ScanNextAddress();
                    }
                }

                // Check PIC connection when not scanning
                else if (!scanningAddresses && !waiting)
                {
                    if (DateTime.Now >= nextAllowedRequest &&
                        DateTime.Now >= nextHeartbeat)
                    {
                        nextHeartbeat = DateTime.Now.AddSeconds(1);

                        // SendPacket(IdRequest, "One-second connectivity check", false, true);
                    }
                }
            }
            catch (Exception ex)
            {
                LostConnection("Serial communication error: " + ex.Message);
            }

            UpdateButtons();
        }

        private void ScanButton_Click(object sender, EventArgs e)
        {
            if (scanningAddresses)
            {
                scanningAddresses = false;
                ScanButton.Text = "Scan";
                Info("Address scan cancelled");
                return;
            }

            if (!verified || !serialPort.IsOpen)
            {
                Error("Cannot send: PIC is disconnected or not verified.");
                return;
            }

            if (scanningAddresses)
            {
                Error("Cannot send: I2C scan is still running.");
                return;
            }

            if (waiting)
            {
                Error("Cannot send: Waiting for response from " + currentRequest);
                return;
            }

            ScanResultsListBox.Items.Clear();
            FoundAddressesListBox.Items.Clear();
            scanIndex = 0;
            scanningAddresses = true;
            ScanButton.Text = "Cancel Scan";
            UpdateScanProgress();
            Info("Scanning 00-7F; reserved addresses will be skipped");

            // Start scanning immediately instead of waiting for the timer
            ScanNextAddress();
        }
    }
}