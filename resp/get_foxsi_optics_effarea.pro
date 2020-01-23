FUNCTION get_foxsi_optics_effarea, ENERGY_ARR = energy_arr, MODULE_NUMBER = module_number, $
	OFFAXIS_ANGLE = offaxis_angle, DATA_DIR = data_dir, PLOT = plot, _EXTRA = _extra

;PURPOSE:   Get the FOXSI optics effective area in cm^2 as a function of energy
;           and off-axis angle.
;
;KEYWORD:   MODULE_NUMBER - the module number (0 through 8).  Optic number is used, this is DIFFERENT FROM THE DETECTOR NUMBER.
;			      PLOT - plot to the current device
;			      OFFAXIS_ANGLE - off-axis angle. if array then [pan, tilt] in arcmin
;
;WRITTEN: Steven Christe (21-Jan-15)
;	modified:	LG	2015 Feb	Switched X0->D6 and X6->D0
;	modified:	SM	2019 Dec	Switched to optic module numbers instead of detector position
; modified: MB  2020 Jan  Differenciate among the three foxsi flights using the DATE keyword.

COMMON FOXSI_PARAM ; allows access to the FOXSI COMMON variables.
default, data_dir, 'calibration_data/'
default, offaxis_angle, [0.0, 0.0]
default, module_number, 0

IF n_elements(offaxis_angle) EQ 1 THEN angle = 1/sqrt(2) * [offaxis_angle, offaxis_angle] $
    ELSE angle = offaxis_angle

; Switch X0->D6 and X6->D0 - we do not need this now that we follow the optic number convention
;if MODULE_NUMBER eq 0 then MODULE = 6 else if MODULE_NUMBER eq 6 then MODULE = 0 $
;		else MODULE = MODULE_NUMBER


CASE DATE OF
    ; foxsi1
    1.0679040e+09: files =  GETENV('FOXSIPKG') + '/' + data_dir + 'FOXSI2_' + ['Module_X-' + num2str(MODULE_NUMBER) + '_EA_pan.txt', $
                       'Module_X-' + num2str(MODULE_NUMBER) + '_EA_tilt.txt'] ; for foxsi1 we used the same EA files as for foxsi2.    
    ; foxsi2
    1.1342592e+09: files =  GETENV('FOXSIPKG') + '/' + data_dir + 'FOXSI2_' + ['Module_X-' + num2str(MODULE_NUMBER) + '_EA_pan.txt', $
                       'Module_X-' + num2str(MODULE_NUMBER) + '_EA_tilt.txt']
    ; foxsi3
    1.2522816e+09: files =  GETENV('FOXSIPKG') + '/' + data_dir + 'FOXSI3_' + ['Module_X-' + num2str(MODULE_NUMBER) + '_EA_pan.txt', $
                       'Module_X-' + num2str(MODULE_NUMBER) + '_EA_tilt.txt']
    ELSE: PRINT, 'DATE has an illegal value.'
ENDCASE

energy = [4.5,  5.5,  6.5,  7.5,  8.5,  9.5, 11. , 13. , 15. , 17. , 19. , 22.5, 27.5]; all effarea use same energy bins
angles = READ_ASCII(files[0], DATA_START=3, NUM_RECORDS=1, DELIMITER=","); angles provided by the data files themselves

FOR i = 0, n_elements(files)-1 DO BEGIN
    ; the following code fills all effare into the data array variable
    IF i EQ 0 THEN data = fltarr(2, n_elements(angles.field01), n_elements(energy))
    FOR j = 0, n_elements(energy)-1 DO BEGIN
      dummy = READ_ASCII(files[i], DATA_START=4+j, NUM_RECORDS=1, DELIMITER=",");dummy var needed to pass field01
      data[i, *, j] = dummy.field01
    ENDFOR
ENDFOR

IF keyword_set(energy_arr) THEN BEGIN
    interpol_data = fltarr(2, n_elements(data[0, *, 0]), n_elements(energy_arr))
    ; interpolate data on new energies    
    FOR j = 0, 2 - 1 DO BEGIN
        FOR i = 0, n_elements(angles)-1 DO BEGIN
            eff_area = data[j, i, *]
            interpol_data[j, i, *] = interpol(eff_area, energy, energy_arr)
        ENDFOR
    ENDFOR
ENDIF ELSE BEGIN 
    interpol_data = data
	energy_arr = energy
ENDELSE

rnorm = sqrt(angle[0] ^ 2 + angle[1] ^ 2)
IF rnorm EQ 0 THEN phi = 0 ELSE phi = atan(abs(angle[1] / angle[0]) )

; now interpolate to the requested off-axis angle
eff_area = fltarr(2, n_elements(energy_arr))


FOR j = 0, 2 - 1 DO FOR i = 0, n_elements(energy_arr)-1 DO BEGIN
    eff_area[j, i] = interpol(interpol_data[j, *, i], angles.field01, rnorm)
ENDFOR

; now interpolate between pan and tilt
m = (eff_area[1, *] - eff_area[0, *]) / !pi/2. 
result = eff_area[0, *] + m * phi
eff_area = result

IF keyword_set(PLOT) THEN BEGIN
	plot, energy_arr, reform(eff_area), psym = -4, $
		xtitle = "Energy [keV]", ytitle = "Effective Area [cm!U2!N]", charsize = 1.5, /xstyle, xrange = [min(energy_arr), max(energy_arr)], _EXTRA = _EXTRA, /nodata
	oplot, energy_arr, reform(eff_area), psym = -4
	ssw_legend, 'pan, tilt = [' + num2str(angle[0]) + ',' + num2str(angle[1]) + ']'
ENDIF

result = create_struct("energy_keV", energy_arr, "eff_area_cm2", eff_area)

RETURN, result

END
