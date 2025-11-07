resource "yandex_compute_snapshot_schedule" "daily_snapshots" {
  name = "daily-snapshots"

  schedule_policy {
    expression = "0 15 ? * *" # ежедневно в 15:00 UTC (18:00 по Мск)
  }

  snapshot_count = 7

  snapshot_spec {
    description = "Ежедневные снапшоты дисков всех ВМ, хранение 7 дней"
  }

  disk_ids = [
    yandex_compute_instance.web["web1"].boot_disk[0].disk_id,
    yandex_compute_instance.web["web2"].boot_disk[0].disk_id,
    yandex_compute_instance.bastion.boot_disk[0].disk_id,
    yandex_compute_instance.zabbix.boot_disk[0].disk_id,
    yandex_compute_instance.elasticsearch.boot_disk[0].disk_id,
    yandex_compute_instance.kibana.boot_disk[0].disk_id
  ]

  depends_on = [
    yandex_compute_instance.web,
    yandex_compute_instance.bastion,
    yandex_compute_instance.zabbix,
    yandex_compute_instance.elasticsearch,
    yandex_compute_instance.kibana
  ]
}