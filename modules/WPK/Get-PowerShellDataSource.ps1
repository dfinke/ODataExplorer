function Get-PowerShellDataSource {
    <#
    .Synopsis
        Gets a new PowerShell data source
    .Description
        Gets a new PowerShell data source.
        PowerShell data sources are used within a WPF application or WPK script
        to provide data from PowerShell to the UI asynchronously.
        This allows you to see the output of a long-running script within a UI 
        while it is still running.
        You can bind this data source to a listbox or listview in order to see its 
        contents
    .Example
    New-ListBox -MaxHeight 350 -DataContext {
        Get-PowerShellDataSource -Script {
            Get-Process | ForEach-Object { $_ ; Start-Sleep -Milliseconds 100 }
        }
    } -DataBinding @{
        ItemsSource = New-Binding -IsAsync -UpdateSourceTrigger PropertyChanged -Path Output
    } -On_Loaded {
        Register-PowerShellCommand -Run -In "0:0:2.5" -ScriptBlock {
            $window.Content.DataContext.Script = $window.Content.DataContext.Script
        }
    } -asjob  
    #>
    param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ScriptBlock]$Script,
    
    [System.Management.Automation.ScriptBlock[]]
    ${On_PropertyChanged}    
    )
    
    begin {
if (-not ('WPK.PowerShellDataSource' -as [Type])) {
Add-Type -IgnoreWarnings -ReferencedAssemblies WindowsBase, PresentationFramework, PresentationCore @'
using System;
using System.Collections.Generic;
using System.Text;
using System.ComponentModel;
using System.Collections.ObjectModel;
using System.Management.Automation;
using System.Windows;
using System.Collections;
using System.Management.Automation.Runspaces;
using System.Timers;
 
namespace WPK
{
    public class PowerShellDataSource : INotifyPropertyChanged
    {
        public IEnumerable Output
        {
            get
            {
                PSObject[] returnValue = new PSObject[outputCollection.Count];
                outputCollection.CopyTo(returnValue, 0);
                return returnValue;
            }
        }
 
 
        PSObject lastOutput;
        public PSObject LastOutput
        {
            get
            {
                return lastOutput;
            }
        }
 
        public IEnumerable Error
        {
            get
            {
                ErrorRecord[] returnValue = new ErrorRecord[powerShellCommand.Streams.Error.Count];
                powerShellCommand.Streams.Error.CopyTo(returnValue, 0);
                return returnValue;
            }
        }
 
        ErrorRecord lastError;
        public ErrorRecord LastError
        {
            get
            {
                return lastError;
            }
        }
 
        public IEnumerable Warning
        {
            get
            {
                WarningRecord[] returnValue = new WarningRecord[powerShellCommand.Streams.Warning.Count];
                powerShellCommand.Streams.Warning.CopyTo(returnValue, 0);
                return returnValue;
            }
        }
 
        WarningRecord lastWarning;
 
        public WarningRecord LastWarning
        {
            get
            {
                return lastWarning;
            }
        }
 
        public IEnumerable Verbose
        {
            get
            {
                VerboseRecord[] returnValue = new VerboseRecord[powerShellCommand.Streams.Verbose.Count];
                powerShellCommand.Streams.Verbose.CopyTo(returnValue, 0);
                return returnValue;
            }
        }
 
        VerboseRecord lastVerbose;
        public VerboseRecord LastVerbose
        {
            get
            {
                return lastVerbose;
            }
        }
 
 
        public IEnumerable Debug
        {
            get
            {
                DebugRecord[] returnValue = new DebugRecord[powerShellCommand.Streams.Debug.Count];
                powerShellCommand.Streams.Debug.CopyTo(returnValue, 0);
                return returnValue;
            }
        }
 
        DebugRecord lastDebug;
        public DebugRecord LastDebug
        {
            get
            {
                return lastDebug;
            }
        }
 
 
        public IEnumerable Progress
        {
            get
            {
                ProgressRecord[] returnValue = new ProgressRecord[powerShellCommand.Streams.Progress.Count];
                powerShellCommand.Streams.Progress.CopyTo(returnValue, 0);
                return returnValue;
            }
        }
 
  
        ProgressRecord lastProgress;
 
        public ProgressRecord LastProgress
        {
            get
            {
                return lastProgress;
            }
        }
        
        public PowerShell Command
        {
            get {
                return powerShellCommand;
            }
        }
 
 
        string script;
 
        public string Script
        {
            get
            {
                return script;
            }
            set
            {
                script = value;
                try
                {
                    powerShellCommand.Commands.Clear();
                    powerShellCommand.AddScript(script, false);
                    lastDebug = null;
                    lastError = null;
                    outputCollection.Clear();
                    lastOutput = null;
                    lastProgress = null;
                    lastVerbose = null;
                    lastWarning = null;
                    if (this.PropertyChanged != null)
                    {
                        PropertyChanged(this, new PropertyChangedEventArgs("Script"));
                        PropertyChanged(this, new PropertyChangedEventArgs("Debug"));
                        PropertyChanged(this, new PropertyChangedEventArgs("LastDebug"));
                        PropertyChanged(this, new PropertyChangedEventArgs("Error"));
                        PropertyChanged(this, new PropertyChangedEventArgs("LastError"));
                        PropertyChanged(this, new PropertyChangedEventArgs("Output"));
                        PropertyChanged(this, new PropertyChangedEventArgs("LastOutput"));
                        PropertyChanged(this, new PropertyChangedEventArgs("Progress"));
                        PropertyChanged(this, new PropertyChangedEventArgs("LastProgress"));
                        PropertyChanged(this, new PropertyChangedEventArgs("Verbose"));
                        PropertyChanged(this, new PropertyChangedEventArgs("LastVerbose"));
                        PropertyChanged(this, new PropertyChangedEventArgs("Warning"));
                        PropertyChanged(this, new PropertyChangedEventArgs("LastWarning"));
                    }
                    powerShellCommand.BeginInvoke<Object, PSObject>(null, outputCollection);
                }
                catch
                {
 
                }
            }
        }
 
        PowerShell powerShellCommand;
        PSDataCollection<PSObject> outputCollection;
        public PowerShellDataSource()
        {
            powerShellCommand =  PowerShell.Create();
            Runspace runspace = RunspaceFactory.CreateRunspace();
            runspace.Open();
            powerShellCommand.Runspace = runspace;
            outputCollection = new PSDataCollection<PSObject>();
            outputCollection.DataAdded += new EventHandler<DataAddedEventArgs>(outputCollection_DataAdded);
            powerShellCommand.Streams.Progress.DataAdded += new EventHandler<DataAddedEventArgs>(Progress_DataAdded);
        }
 
 
        void Initialize()
        {
            powerShellCommand.Streams.Debug.DataAdded += new EventHandler<DataAddedEventArgs>(Debug_DataAdded);
            powerShellCommand.Streams.Error.DataAdded += new EventHandler<DataAddedEventArgs>(Error_DataAdded);
            outputCollection = new PSDataCollection<PSObject>();
            outputCollection.DataAdded += new EventHandler<DataAddedEventArgs>(outputCollection_DataAdded);
            powerShellCommand.Streams.Progress.DataAdded += new EventHandler<DataAddedEventArgs>(Progress_DataAdded);
            powerShellCommand.Streams.Verbose.DataAdded += new EventHandler<DataAddedEventArgs>(Verbose_DataAdded);
            powerShellCommand.Streams.Warning.DataAdded += new EventHandler<DataAddedEventArgs>(Warning_DataAdded);
        }
 
        void Debug_DataAdded(object sender, DataAddedEventArgs e)
        {
            PSDataCollection<DebugRecord> collection = sender as PSDataCollection<DebugRecord>;
            lastDebug = collection[e.Index];
            if (PropertyChanged != null)
            {
                PropertyChanged(this, new PropertyChangedEventArgs("Debug"));
                PropertyChanged(this, new PropertyChangedEventArgs("LastDebug"));
            }                                                
        }
 
        void Error_DataAdded(object sender, DataAddedEventArgs e)
        {
            PSDataCollection<ErrorRecord> collection = sender as PSDataCollection<ErrorRecord>;
            lastError = collection[e.Index];
            if (PropertyChanged != null)
            {
                PropertyChanged(this, new PropertyChangedEventArgs("Error"));
                PropertyChanged(this, new PropertyChangedEventArgs("LastError"));
            }                                    
        }
 
        void Warning_DataAdded(object sender, DataAddedEventArgs e)
        {
            PSDataCollection<WarningRecord> collection = sender as PSDataCollection<WarningRecord>;
            lastWarning = collection[e.Index];
            if (PropertyChanged != null)
            {
                PropertyChanged(this, new PropertyChangedEventArgs("Warning"));
                PropertyChanged(this, new PropertyChangedEventArgs("LastWarning"));
            }                        
        }
 
        void Verbose_DataAdded(object sender, DataAddedEventArgs e)
        {
            PSDataCollection<VerboseRecord> collection = sender as PSDataCollection<VerboseRecord>;
            lastVerbose = collection[e.Index];
            if (PropertyChanged != null)
            {
                PropertyChanged(this, new PropertyChangedEventArgs("Verbose"));
                PropertyChanged(this, new PropertyChangedEventArgs("LastVerbose"));
            }                        
        }
 
        void Progress_DataAdded(object sender, DataAddedEventArgs e)
        {
            PSDataCollection<ProgressRecord> collection = sender as PSDataCollection<ProgressRecord>;
            lastProgress = collection[e.Index];
            if (PropertyChanged != null)
            {
                PropertyChanged(this, new PropertyChangedEventArgs("Progress"));
                PropertyChanged(this, new PropertyChangedEventArgs("LastProgress"));
            }            
        }
 
        void outputCollection_DataAdded(object sender, DataAddedEventArgs e)
        {
            PSDataCollection<PSObject> collection = sender as PSDataCollection<PSObject>;
            lastOutput = collection[e.Index];
            if (PropertyChanged != null)
            {
                PropertyChanged(this, new PropertyChangedEventArgs("Output"));
                PropertyChanged(this, new PropertyChangedEventArgs("LastOutput"));
            }
        }
        public event PropertyChangedEventHandler PropertyChanged;
    }
}
'@
}
    }
    
    process {
        try {
            $Object = New-Object WPK.PowerShellDataSource
        } catch {
            throw $_
            return
        }
        $psBoundParameters.Script = $psBoundParameters.Script -as [string] 
        Set-Property -property $psBoundParameters -inputObject $Object
        $Object
    }
   
}
