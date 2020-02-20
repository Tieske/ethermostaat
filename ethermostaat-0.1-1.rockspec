package = "ethermostaat"
version = "0.1-1"
source = {
  url = "https://github.com/Tieske/corowatch/archive/version_1.0.tar.gz",
  dir = "corowatch-version_1.0"
}
description = {
  summary = "Essent/ICY eThermostaat api implementation",
  detailed = [[
    Allows access to the eThermostaat api, for reading and setting values
  ]],
  homepage = "https://github.com/Tieske/corowatch",
  license = "proprietary"
}
dependencies = {
  "lua >= 5.1",
  "luasocket >= 2.1",
  "dkjson >= 2.5",
  "luasec >= 0.5"
}
build = {
  type = "builtin",
  modules = {
    ["ethermostaat.init"] = "src/ethermostaat.lua",
  },
}
