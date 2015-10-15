ipmo .\modules\WPK\WPK.psm1
ipmo .\modules\OData.psm1 -Force

Function Global:Display-Data ($targetObject, $methodName, $window) {

    if(!$methodName) {return}
    
    $window.Cursor = [System.Windows.Input.Cursors]::Wait

    $window.Title = "Retrieving [$methodName] $(Get-Date)"

    $lvwResults = $window | Get-ChildControl lvwResults
    $items = $targetObject.$methodName.Invoke()

    $spOperations = $window | Get-ChildControl spOperations
    $spOperations.Children.Clear()
    
    if($items) {
        $lvwResults.DataContext = @($items)
        @($items)[0].GetOperations() | % {
            $spOperations.Children.Add( (New-Button -Content $_ -Margin 3 -On_Click {
                $lvwResults = $window | Get-ChildControl lvwResults
                $methodName = $this.Content
                if($lvwResults.SelectedItem) {
                    Display-Data $lvwResults.SelectedItem $methodName $window
                } else {
                    [Windows.Messagebox]::show("Please select an item from the results area.")
                }
            } ) )
        }

        $global:propertyNames = @($items)[0] | Get-Member -MemberType noteproperty | select -ExpandProperty name
        $lvwResults.View = (& {
            New-GridView -Columns {
                foreach($propertyName in $propertyNames) {
                    New-GridViewColumn $propertyName
                }
            }
        })
    } else {
        [Windows.Messagebox]::show("Sorry, no data was returned")
    }

    $window.Title = "OData PowerShell Explorer"
    $window.Cursor = [System.Windows.Input.Cursors]::Arrow
}

Function Clear-SPOps ($window){
    $spOperations = $window | Get-ChildControl spOperations
    $spOperations.Children.Clear()
}

Function Clear-Results ($window) {
    $lvwResults = $window | Get-ChildControl lvwResults
    
    $lvwResults.DataContext = $null
    $lvwResults.View = $null
}

Function Global:Display-DataService ($serviceUri, $window) {
    Clear-Results $window
    Clear-SPOps $window 
    
    $lstCollections = $window | Get-ChildControl lstCollections
    $lstCollections.DataContext = $null
    
    $error.Clear()
    try {
        $global:ODataFeed = New-ODataService $serviceUri
        $lstCollections.DataContext = @(($global:ODataFeed).GetOperations())
        $window.Title = "OData PowerShell Explorer"
    } catch { 
        $window.Title = $error[0].Exception.Message
    }
}

New-Window -Title "OData PowerShell Explorer" -WindowStartupLocation CenterScreen -Width 900 -Height 500 -Show -On_Loaded {
    ($window | Get-ChildControl lstCollections).Focus()
    
    $lstODataServices = $window | Get-ChildControl lstODataServices
    $lstODataServices.DataContext = @(Import-Csv .\ODataServices.csv)
} {
    New-Grid -Columns Auto, Auto, Auto, 100* {
    
        New-GroupBox -Header " OData Services " -Column 0 -Margin 5 {
            New-ListBox -Name lstODataServices -Margin 5 -DisplayMemberPath Name -DataBinding @{ ItemsSource = New-Binding } -On_SelectionChanged {
                Display-DataService $this.SelectedItem.uri $window
            }
        }
        
        New-GroupBox -Header " Collections " -Column 1 -Margin 5 {
            New-ListBox -Name lstCollections -Margin 5 -DataBinding @{ ItemsSource = New-Binding } -On_SelectionChanged {
                Display-Data $global:ODataFeed $this.SelectedItem $window
            }
        }

        New-GroupBox -Header " Drill Down " -Column 2 -Margin 5 { New-StackPanel -Name spOperations }

        New-GroupBox -Header " Results " -Column 3 -Margin 5 {
            New-ListView -Name lvwResults -Margin 5 -DataBinding @{ ItemsSource = New-Binding }
        }
    }
}