@echo off
set /p version=Input version:
echo %version%
set scriptDir=%~dp0

call vivado -mode tcl -nojournal -nolog -source pcie_write_cfgmem.tcl

xcopy  %scriptDir%project_1\project_1.runs\impl_1\pcie_card_top.bit  %scriptDir%version_bin\
xcopy  %scriptDir%project_1\project_1.runs\impl_1\pcie_card_top.ltx  %scriptDir%version_bin\
xcopy  %scriptDir%project_1\project_1.runs\impl_1\pcie_card_top.bin  %scriptDir%version_bin\
xcopy  %scriptDir%project_1\project_1.runs\impl_1\pcie_card_top.mcs  %scriptDir%version_bin\

ren  %scriptDir%version_bin\pcie_card_top.bit PCG1_PCIE_v%version%.bit 
ren  %scriptDir%version_bin\pcie_card_top.ltx PCG1_PCIE_v%version%.ltx 
ren  %scriptDir%version_bin\pcie_card_top.bin PCG1_PCIE_v%version%.bin 
ren  %scriptDir%version_bin\pcie_card_top.mcs PCG1_PCIE_v%version%.mcs 

pause