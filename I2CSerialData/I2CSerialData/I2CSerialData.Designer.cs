namespace I2CSerialData
{
    partial class I2CSerialData
    {
        /// <summary>
        ///  Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        ///  Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        ///  Required method for Designer support - do not modify
        ///  the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            components = new System.ComponentModel.Container();
            backgroundWorker1 = new System.ComponentModel.BackgroundWorker();
            ConnectionGroupBox = new GroupBox();
            PortsComboBox = new ComboBox();
            StatusLabel = new Label();
            CommandsGroupBox = new GroupBox();
            PacketPreviewTextBox = new TextBox();
            SendButton = new Button();
            RawFrameTextBox = new TextBox();
            OutputTextBox = new TextBox();
            DataModeComboBox = new ComboBox();
            ReadCountTextBox = new TextBox();
            AddressTextBox = new TextBox();
            OperationComboBox = new ComboBox();
            SavedGroupBox = new GroupBox();
            SendSavedButton = new Button();
            DeleteCommandButton = new Button();
            LoadCommandButton = new Button();
            SaveCommandButton = new Button();
            SavedCommandsComboBox = new ComboBox();
            SavedNameTextBox = new TextBox();
            ScannerGroupBox = new GroupBox();
            FoundAddressesListBox = new ListBox();
            ScanResultsListBox = new ListBox();
            ScanStatusLabel = new Label();
            ScanButton = new Button();
            HistoryGroupBox = new GroupBox();
            ExitButton = new Button();
            ComListBox = new ListBox();
            StatusTimer = new System.Windows.Forms.Timer(components);
            ConnectionGroupBox.SuspendLayout();
            CommandsGroupBox.SuspendLayout();
            SavedGroupBox.SuspendLayout();
            ScannerGroupBox.SuspendLayout();
            HistoryGroupBox.SuspendLayout();
            SuspendLayout();
            // 
            // ConnectionGroupBox
            // 
            ConnectionGroupBox.Controls.Add(PortsComboBox);
            ConnectionGroupBox.Controls.Add(StatusLabel);
            ConnectionGroupBox.Location = new Point(12, 12);
            ConnectionGroupBox.Name = "ConnectionGroupBox";
            ConnectionGroupBox.Size = new Size(170, 110);
            ConnectionGroupBox.TabIndex = 0;
            ConnectionGroupBox.TabStop = false;
            ConnectionGroupBox.Text = "Connection Status";
            // 
            // PortsComboBox
            // 
            PortsComboBox.FormattingEnabled = true;
            PortsComboBox.Location = new Point(6, 67);
            PortsComboBox.Name = "PortsComboBox";
            PortsComboBox.Size = new Size(151, 28);
            PortsComboBox.TabIndex = 1;
            // 
            // StatusLabel
            // 
            StatusLabel.AutoSize = true;
            StatusLabel.Location = new Point(6, 32);
            StatusLabel.Name = "StatusLabel";
            StatusLabel.Size = new Size(99, 20);
            StatusLabel.TabIndex = 0;
            StatusLabel.Text = "Disconnected";
            // 
            // CommandsGroupBox
            // 
            CommandsGroupBox.Controls.Add(PacketPreviewTextBox);
            CommandsGroupBox.Controls.Add(SendButton);
            CommandsGroupBox.Controls.Add(RawFrameTextBox);
            CommandsGroupBox.Controls.Add(OutputTextBox);
            CommandsGroupBox.Controls.Add(DataModeComboBox);
            CommandsGroupBox.Controls.Add(ReadCountTextBox);
            CommandsGroupBox.Controls.Add(AddressTextBox);
            CommandsGroupBox.Controls.Add(OperationComboBox);
            CommandsGroupBox.Location = new Point(199, 12);
            CommandsGroupBox.Name = "CommandsGroupBox";
            CommandsGroupBox.Size = new Size(522, 328);
            CommandsGroupBox.TabIndex = 1;
            CommandsGroupBox.TabStop = false;
            CommandsGroupBox.Text = "UART / I2C Commands";
            // 
            // PacketPreviewTextBox
            // 
            PacketPreviewTextBox.Location = new Point(15, 234);
            PacketPreviewTextBox.Name = "PacketPreviewTextBox";
            PacketPreviewTextBox.Size = new Size(501, 27);
            PacketPreviewTextBox.TabIndex = 7;
            // 
            // SendButton
            // 
            SendButton.Location = new Point(15, 268);
            SendButton.Name = "SendButton";
            SendButton.Size = new Size(501, 49);
            SendButton.TabIndex = 6;
            SendButton.Text = "Send Command";
            SendButton.UseVisualStyleBackColor = true;
            SendButton.Click += SendButton_Click;
            // 
            // RawFrameTextBox
            // 
            RawFrameTextBox.Location = new Point(15, 201);
            RawFrameTextBox.Name = "RawFrameTextBox";
            RawFrameTextBox.Size = new Size(501, 27);
            RawFrameTextBox.TabIndex = 5;
            // 
            // OutputTextBox
            // 
            OutputTextBox.Location = new Point(15, 168);
            OutputTextBox.Name = "OutputTextBox";
            OutputTextBox.Size = new Size(501, 27);
            OutputTextBox.TabIndex = 4;
            OutputTextBox.Text = "01 41";
            // 
            // DataModeComboBox
            // 
            DataModeComboBox.FormattingEnabled = true;
            DataModeComboBox.Location = new Point(15, 134);
            DataModeComboBox.Name = "DataModeComboBox";
            DataModeComboBox.Size = new Size(501, 28);
            DataModeComboBox.TabIndex = 3;
            // 
            // ReadCountTextBox
            // 
            ReadCountTextBox.Location = new Point(15, 101);
            ReadCountTextBox.Name = "ReadCountTextBox";
            ReadCountTextBox.Size = new Size(501, 27);
            ReadCountTextBox.TabIndex = 2;
            ReadCountTextBox.Text = "1";
            // 
            // AddressTextBox
            // 
            AddressTextBox.Location = new Point(15, 68);
            AddressTextBox.Name = "AddressTextBox";
            AddressTextBox.Size = new Size(501, 27);
            AddressTextBox.TabIndex = 1;
            AddressTextBox.Text = "20";
            // 
            // OperationComboBox
            // 
            OperationComboBox.FormattingEnabled = true;
            OperationComboBox.Location = new Point(15, 32);
            OperationComboBox.Name = "OperationComboBox";
            OperationComboBox.Size = new Size(501, 28);
            OperationComboBox.TabIndex = 0;
            // 
            // SavedGroupBox
            // 
            SavedGroupBox.Controls.Add(SendSavedButton);
            SavedGroupBox.Controls.Add(DeleteCommandButton);
            SavedGroupBox.Controls.Add(LoadCommandButton);
            SavedGroupBox.Controls.Add(SaveCommandButton);
            SavedGroupBox.Controls.Add(SavedCommandsComboBox);
            SavedGroupBox.Controls.Add(SavedNameTextBox);
            SavedGroupBox.Location = new Point(12, 128);
            SavedGroupBox.Name = "SavedGroupBox";
            SavedGroupBox.Size = new Size(170, 310);
            SavedGroupBox.TabIndex = 2;
            SavedGroupBox.TabStop = false;
            SavedGroupBox.Text = "Saved Commands";
            // 
            // SendSavedButton
            // 
            SendSavedButton.Location = new Point(11, 264);
            SendSavedButton.Name = "SendSavedButton";
            SendSavedButton.Size = new Size(151, 40);
            SendSavedButton.TabIndex = 6;
            SendSavedButton.Text = "Retransmit";
            SendSavedButton.UseVisualStyleBackColor = true;
            SendSavedButton.Click += SendSavedButton_Click;
            // 
            // DeleteCommandButton
            // 
            DeleteCommandButton.Location = new Point(11, 218);
            DeleteCommandButton.Name = "DeleteCommandButton";
            DeleteCommandButton.Size = new Size(151, 40);
            DeleteCommandButton.TabIndex = 5;
            DeleteCommandButton.Text = "Delete";
            DeleteCommandButton.UseVisualStyleBackColor = true;
            DeleteCommandButton.Click += DeleteCommandButton_Click;
            // 
            // LoadCommandButton
            // 
            LoadCommandButton.Location = new Point(11, 171);
            LoadCommandButton.Name = "LoadCommandButton";
            LoadCommandButton.Size = new Size(151, 41);
            LoadCommandButton.TabIndex = 4;
            LoadCommandButton.Text = "Load/Edit";
            LoadCommandButton.UseVisualStyleBackColor = true;
            LoadCommandButton.Click += LoadCommandButton_Click;
            // 
            // SaveCommandButton
            // 
            SaveCommandButton.Location = new Point(11, 129);
            SaveCommandButton.Name = "SaveCommandButton";
            SaveCommandButton.Size = new Size(151, 38);
            SaveCommandButton.TabIndex = 3;
            SaveCommandButton.Text = "Save/Upload";
            SaveCommandButton.UseVisualStyleBackColor = true;
            SaveCommandButton.Click += SaveCommandButton_Click;
            // 
            // SavedCommandsComboBox
            // 
            SavedCommandsComboBox.FormattingEnabled = true;
            SavedCommandsComboBox.Location = new Point(6, 63);
            SavedCommandsComboBox.Name = "SavedCommandsComboBox";
            SavedCommandsComboBox.Size = new Size(151, 28);
            SavedCommandsComboBox.TabIndex = 1;
            // 
            // SavedNameTextBox
            // 
            SavedNameTextBox.Location = new Point(6, 30);
            SavedNameTextBox.Name = "SavedNameTextBox";
            SavedNameTextBox.Size = new Size(151, 27);
            SavedNameTextBox.TabIndex = 0;
            // 
            // ScannerGroupBox
            // 
            ScannerGroupBox.Controls.Add(FoundAddressesListBox);
            ScannerGroupBox.Controls.Add(ScanResultsListBox);
            ScannerGroupBox.Controls.Add(ScanStatusLabel);
            ScannerGroupBox.Controls.Add(ScanButton);
            ScannerGroupBox.Location = new Point(727, 12);
            ScannerGroupBox.Name = "ScannerGroupBox";
            ScannerGroupBox.Size = new Size(297, 328);
            ScannerGroupBox.TabIndex = 3;
            ScannerGroupBox.TabStop = false;
            ScannerGroupBox.Text = "I2C Address Scanner";
            // 
            // FoundAddressesListBox
            // 
            FoundAddressesListBox.FormattingEnabled = true;
            FoundAddressesListBox.Location = new Point(6, 253);
            FoundAddressesListBox.Name = "FoundAddressesListBox";
            FoundAddressesListBox.Size = new Size(285, 64);
            FoundAddressesListBox.TabIndex = 3;
            // 
            // ScanResultsListBox
            // 
            ScanResultsListBox.FormattingEnabled = true;
            ScanResultsListBox.Location = new Point(6, 103);
            ScanResultsListBox.Name = "ScanResultsListBox";
            ScanResultsListBox.Size = new Size(285, 144);
            ScanResultsListBox.TabIndex = 2;
            // 
            // ScanStatusLabel
            // 
            ScanStatusLabel.AutoSize = true;
            ScanStatusLabel.Location = new Point(6, 75);
            ScanStatusLabel.Name = "ScanStatusLabel";
            ScanStatusLabel.Size = new Size(94, 20);
            ScanStatusLabel.TabIndex = 1;
            ScanStatusLabel.Text = "Not Scanned";
            // 
            // ScanButton
            // 
            ScanButton.Location = new Point(6, 19);
            ScanButton.Name = "ScanButton";
            ScanButton.Size = new Size(285, 46);
            ScanButton.TabIndex = 0;
            ScanButton.Text = "Scan I2C Bus";
            ScanButton.UseVisualStyleBackColor = true;
            ScanButton.Click += ScanButton_Click;
            // 
            // HistoryGroupBox
            // 
            HistoryGroupBox.Controls.Add(ExitButton);
            HistoryGroupBox.Controls.Add(ComListBox);
            HistoryGroupBox.Location = new Point(199, 346);
            HistoryGroupBox.Name = "HistoryGroupBox";
            HistoryGroupBox.Size = new Size(825, 92);
            HistoryGroupBox.TabIndex = 4;
            HistoryGroupBox.TabStop = false;
            HistoryGroupBox.Text = "Communication History";
            // 
            // ExitButton
            // 
            ExitButton.Location = new Point(679, 22);
            ExitButton.Name = "ExitButton";
            ExitButton.Size = new Size(134, 64);
            ExitButton.TabIndex = 1;
            ExitButton.Text = "Exit";
            ExitButton.UseVisualStyleBackColor = true;
            ExitButton.Click += ExitButton_Click;
            // 
            // ComListBox
            // 
            ComListBox.FormattingEnabled = true;
            ComListBox.Location = new Point(6, 22);
            ComListBox.Name = "ComListBox";
            ComListBox.Size = new Size(667, 64);
            ComListBox.TabIndex = 0;
            // 
            // StatusTimer
            // 
            StatusTimer.Interval = 20;
            StatusTimer.Tick += StatusTimer_Tick;
            // 
            // I2CSerialData
            // 
            AutoScaleDimensions = new SizeF(8F, 20F);
            AutoScaleMode = AutoScaleMode.Font;
            ClientSize = new Size(1051, 450);
            Controls.Add(HistoryGroupBox);
            Controls.Add(ScannerGroupBox);
            Controls.Add(SavedGroupBox);
            Controls.Add(CommandsGroupBox);
            Controls.Add(ConnectionGroupBox);
            Name = "I2CSerialData";
            Text = "Form1";
            ConnectionGroupBox.ResumeLayout(false);
            ConnectionGroupBox.PerformLayout();
            CommandsGroupBox.ResumeLayout(false);
            CommandsGroupBox.PerformLayout();
            SavedGroupBox.ResumeLayout(false);
            SavedGroupBox.PerformLayout();
            ScannerGroupBox.ResumeLayout(false);
            ScannerGroupBox.PerformLayout();
            HistoryGroupBox.ResumeLayout(false);
            ResumeLayout(false);
        }

        #endregion

        private System.ComponentModel.BackgroundWorker backgroundWorker1;
        private GroupBox ConnectionGroupBox;
        private ComboBox PortsComboBox;
        private Label StatusLabel;
        private GroupBox CommandsGroupBox;
        private TextBox AddressTextBox;
        private ComboBox OperationComboBox;
        private ComboBox DataModeComboBox;
        private TextBox ReadCountTextBox;
        private TextBox RawFrameTextBox;
        private TextBox OutputTextBox;
        private Button SendButton;
        private GroupBox SavedGroupBox;
        private ComboBox SavedCommandsComboBox;
        private TextBox SavedNameTextBox;
        private Button SendSavedButton;
        private Button DeleteCommandButton;
        private Button LoadCommandButton;
        private Button SaveCommandButton;
        private GroupBox ScannerGroupBox;
        private ListBox ScanResultsListBox;
        private Label ScanStatusLabel;
        private Button ScanButton;
        private ListBox FoundAddressesListBox;
        private GroupBox HistoryGroupBox;
        private Button ExitButton;
        private ListBox ComListBox;
        private System.Windows.Forms.Timer StatusTimer;
        private TextBox PacketPreviewTextBox;
    }
}
