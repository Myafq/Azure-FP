$rgname = 'FinalProject'
$location = 'centralus'
$adminuser = 'fpsuperuser'
$saname = 'fpwpresources'
$vmssname = 'fpvmss'
$dbsrvname = 'mysqlfpwp'
$dbuser = 'fpwpdbuser'
$dbpassword = 'fpwpDBpass1'

New-AzResourceGroup -Name $rgname -Location $location -Force

# Create storage account and files share for vmss. Also create blob store to put initial script to
New-AzResourceGroupDeployment -ResourceGroupName $rgname  -Name $rgname -SAName $saname -TemplateFile ./templates/ShareStorageAcc.json
$sakey = Get-AzStorageAccountKey -ResourceGroupName $rgname -Name $saname 
$scontext = New-AzStorageContext -StorageAccountName $saname -StorageAccountKey $sakey.value[0] 
$blobname = 'files'
$scriptname = 'shell.sh'
New-AzStorageShare -Name ('fs'+$saname) -Context $scontext -ErrorAction Ignore
New-AzStorageContainer -Name $blobname -Context $scontext -ErrorAction Ignore
Set-AzStorageBlobContent -Container $blobname -File $scriptname -Context $scontext -Force 
$fileuri = ('https://' + $saname + '.blob.core.windows.net/' + $blobname + '/' + $scriptname)

if($Args[0] -eq 'ssl')
{
    #Create vpn keys and root CA for vpn gateway
    openssl genrsa -des3 -out keys/rootCA.key 4096 
    openssl req -x509 -new -nodes -key keys/rootCA.key -sha256 -days 1024 -out keys/rootCA.crt

    openssl genrsa -out keys/admin.key 2048
    openssl req -new -sha256 -key keys/admin.key -subj "/C=US/ST=CA/O=MyOrg, Inc./CN=admin" -out keys/admin.csr
    openssl x509 -req -in keys/admin.csr -CA keys/rootCA.crt -CAkey keys/rootCA.key -CAcreateserial -out keys/admin.crt -days 500 -sha256
    #Create user certificate for mac user
    openssl pkcs12 -in keys/admin.crt -inkey keys/admin.key -certfile keys/rootCA.crt -export -out keys/admin.p12
}
$sshkey = Get-Content -Path $HOME/.ssh/id_rsa.pub
$rootca = cat ./keys/rootCA.crt | base64

# create everything
# DSC doesn't work on mac and work hard on linux. fuck it.
New-AzResourceGroupDeployment -vmssName $vmssname -instanceCount 2 -sshPublicKey $sshkey -storageAccountName $saname `
    -storageAccountKey $sakey.value[0] -shareName ('fs'+$saname) -ResourceGroupName $rgname -Name 'vmssdeploy' `
    -TemplateFile ./templates/VMSS.json  -adminUsername $adminuser -Verbose -clientRootCertData $rootca -scriptUri $fileuri `
    -dbadmin $dbuser -dbadminPassword $dbpassword -dbserverName $dbsrvname -location $location
