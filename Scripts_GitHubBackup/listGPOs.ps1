# List GPOs
# Paul Ohashi
# TCI
CLS

Get-GPO -All |
    Sort-Object CreationTime -Descending |
    Select DisplayName,CreationTime,Owner