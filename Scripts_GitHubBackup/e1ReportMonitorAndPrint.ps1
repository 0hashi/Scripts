# Define paths and printer
$sourceFolder = "C:\SourceFolder"          # Directory to monitor
$destinationFolder = "C:\ProcessedFolder"  # Where to move files after printing
$printerName = "Your_Printer_Name"         # Name of your printer (check in Control Panel > Devices and Printers)

# Create destination folder if it doesn't exist
if (!(Test-Path -Path $destinationFolder)) {
    New-Item -ItemType Directory -Path $destinationFolder
}

# Create FileSystemWatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $sourceFolder
$watcher.Filter = "*.pdf"
$watcher.IncludeSubdirectories = $false
$watcher.EnableRaisingEvents = $true

# Define the action to take when a PDF is created
$action = {
    $filePath = $Event.SourceEventArgs.FullPath
    $fileName = $Event.SourceEventArgs.Name
    $changeType = $Event.SourceEventArgs.ChangeType
    
    # Wait briefly to ensure file is fully written
    Start-Sleep -Seconds 2
    
    try {
        # Print the PDF file
        Start-Process -FilePath $filePath -Verb Print -ArgumentList "-printer $printerName" -Wait
        
        # Generate new filename with timestamp
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $newFileName = "$($fileName.Split('.')[0])_$timestamp.pdf"
        $destinationPath = Join-Path -Path $destinationFolder -ChildPath $newFileName
        
        # Move and rename the file
        Move-Item -Path $filePath -Destination $destinationPath -Force
        
        Write-Host "Processed: $fileName - Printed and moved to $destinationPath"
    }
    catch {
        Write-Host "Error processing $fileName : $_"
    }
}

# Register the event
Register-ObjectEvent -InputObject $watcher -EventName "Created" -Action $action

# Keep script running
Write-Host "Monitoring $sourceFolder for new PDF files. Press Ctrl+C to stop."
while ($true) { Start-Sleep -Seconds 1 }