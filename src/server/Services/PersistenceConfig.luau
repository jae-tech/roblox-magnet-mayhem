--!strict
-- Studio access is deliberately opt-in and uses a separate store.
return table.freeze({
	productionStore = "MagnetMayhem_PlayerData_v1",
	studioStore = "MagnetMayhem_PlayerData_Studio_v1",
	allowStudioDataStore = false,
	leaseSeconds = 180,
	autosaveSeconds = 60,
	leaseSafetyMargin = 15,
	loadAttempts = 3,
	saveAttempts = 3,
	operationDeadlineSeconds = 20,
	closeDeadlineSeconds = 25,
})
