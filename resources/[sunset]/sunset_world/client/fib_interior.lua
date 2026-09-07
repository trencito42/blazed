local function requestFibIpls()
    RequestIpl('FIBlobby')
    RequestIpl('FIB_01')
    RequestIpl('atriumglmission')
end

CreateThread(function()
    requestFibIpls()
    Wait(5000)
    requestFibIpls()
end)
