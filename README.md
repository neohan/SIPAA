SIPAA
=====
基于FreeSWITCH软件的自动话务台应用。使用了sqlite数据库，数据库文件与FreeSWITCH的核心数据库在同一目录下。实现应用的逻辑用lua语言编写。

tsimplify.lua
文件的作用是：在目标话机接通时，FreeSWITCH将调用此脚本，将来电转给目标话机。
