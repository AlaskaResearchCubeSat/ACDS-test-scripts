%prompt to calibrate
fprintf('Make sure sensor is in the helmholtz cage and the Sattelite is removed.\nPress Enter when ready');
pause;
%calibrate Helmholtz cage
printf('Calibrating Helmholtz cage\n');
cc=cage_control();
err=cc.calibrate()
if err<1
    cc.saveCal('calibration.cal');
else
    delete(cc);
    error('Calibration Failed');
end
delete(cc);
%prompt to add prototype
fprintf('Place Sattelite in Helmholtz cage alligned with the sensor axis and plug in USB cable\nPress Enter when ready');
pause;
%run to calibrate for flight
store_all_cal([],[],-93.5,NaN);
%complete
fprintf('Calibration Complete!!n');
