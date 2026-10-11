-- Extra autostart processes (Serpantinum Shell).
hl.exec_cmd("serpantinumd start")

-- Fix AMD + NVIDIA hybrid GPU video decoding on Wayland:
-- Omarchy exports LIBVA_DRIVER_NAME=nvidia globally, which breaks
-- hardware video decoding on the internal screen powered by the AMD Radeon iGPU.
-- Setting it to radeonsi enables hardware decoding on AMD Phoenix 780M graphics.
hl.env("LIBVA_DRIVER_NAME", "radeonsi")
hl.exec_cmd("systemctl --user import-environment LIBVA_DRIVER_NAME")


