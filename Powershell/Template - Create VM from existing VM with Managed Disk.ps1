$sourceSubscriptionId = "source subscription"
$targetSubscriptionId = "target subscription"
$sourceResourceGroupName = "source resource group"
$targetResourceGroupName = "target resource group"
$targetRegion = "region"
$VMName = “source vm name”
#$availabilitySet = "source availability set"
$targetNICName = "target nic"
$targetVNetName = "target vnet"
$subnetName = "target subnet"
$addressPrefix = "target vnet ip address"
$diagStorageAccountName = "storage account name"
#$PlanName = 'byol-1061'
#$PlanProduct = 'arcgis-enterprise-106'
#$PlanPublisher = 'esri'

# Login to Azure
Connect-azAccount

# Select source subscription
Set-azContext -Subscription $sourceSubscriptionId

# Get the VM
$sourceVM = Get-azVM -ResourceGroupName $sourceResourceGroupName -Name $VMName

# Stop the VM
Stop-azVM -ResourceGroupName $sourceResourceGroupName -Name $VMName -Force

# Get the managed OS disk
$sourceManagedDisk = Get-azDisk -ResourceGroupName $sourceResourceGroupName -DiskName $sourceVM.StorageProfile.OsDisk.Name

# Add logic to get data disks if any

# Select target subscription
Set-azContext -Subscription $targetSubscriptionId

# Create target resource group
$targetResourceGroup = Get-azResourceGroup -Name $targetResourceGroupName -Location "south africa north" -InformationAction SilentlyContinue -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
if ($targetResourceGroup -eq $null)
{
    New-azResourceGroup -Name $targetResourceGroupName -Location $targetRegion -InformationAction SilentlyContinue
}

$newDiskConfig = New-azDiskConfig -SourceResourceId $sourceManagedDisk.Id -Location $targetRegion -CreateOption Copy
$newDisk = New-azDisk -Disk $newDiskConfig -DiskName $sourceManagedDisk.Name -ResourceGroupName $targetResourceGroupName

# Add logic to copy data disks if any

# Create the virtual network (if not existing)
$newSubnet = $null
$vNet = Get-azVirtualNetwork -Name $targetVNetName -ResourceGroupName $targetResourceGroupName -InformationAction SilentlyContinue -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
if ($vNet -eq $null)
{
    $newSubnet = New-azVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $addressPrefix -InformationAction SilentlyContinue
    $vNet = New-azVirtualNetwork -Name $targetVNetName -ResourceGroupName $targetResourceGroupName -Location $targetRegion -AddressPrefix $addressPrefix -Subnet $newSubnet -InformationAction SilentlyContinue
}
$newSubnet = Get-azVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vNet -InformationAction SilentlyContinue


# Create the new network interface
$newNIC = New-azNetworkInterface -Name $targetNICName -ResourceGroupName $targetResourceGroupName -SubnetId $newSubnet.Id -Location $targetRegion -InformationAction SilentlyContinue

# Accept licence terms for the publisher plan
#Get-azMarketplaceTerms -Publisher $PlanPublisher -Product $PlanProduct -Name $PlanName | Set-azMarketplaceTerms -Accept

# Create the availability set
$targetAvSet = New-azAvailabilitySet -ResourceGroupName $targetResourceGroupName -Name $availabilitySet -Location $targetRegion -Sku 'Aligned' -PlatformUpdateDomainCount 2 -PlatformFaultDomainCount 2 -InformationAction SilentlyContinue

# Create the virtual machine
$newVM = New-azVMConfig -VMName $sourceVM.Name -VMSize $sourceVM.HardwareProfile.VmSize -AvailabilitySetId $targetAvSet.Id
$newVM = Set-azVMOSDisk -VM $newVM -ManagedDiskId $newDisk.Id -CreateOption Attach -Windows
$newVM = Add-azVMNetworkInterface -VM $newVM -Id $newNIC.Id
#$newVM.Plan = New-Object -TypeName 'Microsoft.Azure.Management.Compute.Models.Plan'
#$newVM.Plan.Name = $PlanName
#$newVM.Plan.Product = $PlanProduct
#$newVM.Plan.Publisher = $PlanPublisher
$newVM = Set-azVMBootDiagnostics -VM $newVM -Enable -StorageAccountName $diagStorageAccountName -ResourceGroupName $targetResourceGroupName
New-azVM -VM $newVM -ResourceGroupName $targetResourceGroupName -Location "south africa north" 

