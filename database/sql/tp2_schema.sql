create table if not exists weather_sensor_clean (
   event_id         uuid primary key,
   observed_at      timestamptz not null,
   collected_at     timestamptz not null,
   source           varchar(80) not null,
   temperature_c    numeric(6,2),
   humidity_pct     numeric(6,2),
   wind_speed_kmh   numeric(8,2),
   precipitation_mm numeric(8,2) not null default 0,
   sensor_gid       integer not null
      references sensor ( gid ),
   sensor_ident     varchar(30) not null,
   sensor_type      varchar(30) not null,
   zone             integer not null,
   sensor_latitude  numeric(10,7) not null,
   sensor_longitude numeric(10,7) not null,
   sensor_label     text not null,
   comptage_5m      integer check ( comptage_5m is null
       or comptage_5m >= 0 ),
   processed_at     timestamptz not null default current_timestamp
);

create index if not exists weather_sensor_observed_idx on
   weather_sensor_clean (
      observed_at
   );
create index if not exists weather_sensor_zone_idx on
   weather_sensor_clean (
      zone
   );