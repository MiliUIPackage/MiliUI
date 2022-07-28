Exlist = {
   constants = {},
   ModuleData = {
      updaters = {}, -- [event] = {name,key,override,func)}
      lineGenerators = {}, -- [i] = {name,func,prio,key,type}
      modules = {}, -- [key] = {name,enabled,description,modernizeFunc,initFunc,events}
      resetHandle = {} -- [key] = {weekly,daily,handler}
   }
}
Exlist_Config = Exlist_Config or {}
Exlist.L = {}
ExlistTimers = {}
LibStub("AceTimer-3.0"):Embed(ExlistTimers)
Exlist.timers = ExlistTimers
