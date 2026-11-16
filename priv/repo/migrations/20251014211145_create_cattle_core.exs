defmodule Cattle.Repo.Migrations.CreateCattleCore do
  use Ecto.Migration

  # SQLite can't add constraints to an existing table, so every CHECK is
  # declared inline with its column via `check: %{name: ..., expr: ...}`.
  # A column-level CHECK may still reference other columns in the row.

  def change do
    create table(:pens) do
      add :name, :string, null: false

      add :capacity, :integer,
        check: %{name: "capacity_positive", expr: "capacity IS NULL OR capacity > 0"}

      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pens, [:name])

    create table(:animals) do
      add :tag, :string, null: false
      add :breed, :string

      add :sex, :string,
        check: %{
          name: "sex_valid",
          expr: "sex IS NULL OR sex IN ('steer', 'heifer', 'bull', 'cow')"
        }

      add :birth_date, :date,
        check: %{
          name: "birth_before_arrival",
          expr: "birth_date IS NULL OR birth_date <= arrival_date"
        }

      add :arrival_date, :date, null: false
      add :source, :string

      add :status, :string,
        null: false,
        default: "active",
        check: %{name: "status_valid", expr: "status IN ('active', 'shipped', 'dead')"}

      add :departure_date, :date,
        check: %{
          name: "departure_after_arrival",
          expr: "departure_date IS NULL OR departure_date >= arrival_date"
        }

      add :pen_id, references(:pens, on_delete: :nothing)

      # An animal has a departure date exactly when it is no longer active.
      add :notes, :text,
        check: %{
          name: "departure_matches_status",
          expr: "(status = 'active') = (departure_date IS NULL)"
        }

      timestamps(type: :utc_datetime)
    end

    create unique_index(:animals, [:tag])
    create index(:animals, [:pen_id, :status])

    create table(:weigh_ins) do
      add :animal_id, references(:animals, on_delete: :delete_all), null: false
      add :weighed_on, :date, null: false

      add :weight_lb, :numeric,
        precision: 6,
        scale: 1,
        null: false,
        check: %{name: "weight_positive", expr: "weight_lb > 0"}

      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:weigh_ins, [:animal_id, :weighed_on])

    create table(:health_events) do
      add :animal_id, references(:animals, on_delete: :delete_all), null: false
      add :occurred_on, :date, null: false

      add :kind, :string,
        null: false,
        check: %{
          name: "kind_valid",
          expr: "kind IN ('observation', 'treatment', 'vaccination')"
        }

      add :description, :text, null: false
      add :product, :string
      add :dose, :string

      add :withdrawal_until, :date,
        check: %{
          name: "withdrawal_after_event",
          expr: "withdrawal_until IS NULL OR withdrawal_until >= occurred_on"
        }

      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:health_events, [:animal_id, :occurred_on])
    create index(:health_events, [:withdrawal_until])

    create table(:feedings) do
      add :pen_id, references(:pens, on_delete: :nothing), null: false
      add :fed_on, :date, null: false
      add :feed_type, :string, null: false

      add :amount_lb, :numeric,
        precision: 9,
        scale: 1,
        null: false,
        check: %{name: "amount_positive", expr: "amount_lb > 0"}

      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:feedings, [:pen_id, :fed_on])
  end
end
