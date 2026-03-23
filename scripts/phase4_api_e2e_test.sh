#!/usr/bin/env bash
set -euo pipefail

# Phase 4 API E2E verification (Edge Functions + REST)
# Usage:
#   bash scripts/phase4_api_e2e_test.sh

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT_DIR/flutter_app/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: missing env file at $ENV_FILE"
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required}"
: "${SUPABASE_SERVICE_ROLE_KEY:?SUPABASE_SERVICE_ROLE_KEY is required}"

for bin in curl jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $bin"
    exit 1
  fi
done

REST_URL="$SUPABASE_URL/rest/v1"
FUNC_URL="$SUPABASE_URL/functions/v1"

suffix="$(date +%s)_$RANDOM"
owner_uid="phase4_owner_${suffix}"
member_uid="phase4_member_${suffix}"
task_catalog_id="phase4_task_${suffix}"
shop_item_id="phase4_shop_${suffix}"
achievement_id="phase4_ach_${suffix}"
neighborhood_name="P4 API Neighborhood ${suffix}"

user_task_id=""
neighborhood_id=""
raid_id=""

service_headers=(
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY"
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"
  -H "Content-Type: application/json"
  -H "Prefer: return=representation"
)

func_headers=(
  -H "apikey: $SUPABASE_ANON_KEY"
  -H "Authorization: Bearer $SUPABASE_ANON_KEY"
  -H "Content-Type: application/json"
)

require_true() {
  local msg="$1"
  local val="$2"
  if [[ "$val" != "true" ]]; then
    echo "FAIL: $msg"
    exit 1
  fi
  echo "PASS: $msg"
}

cleanup() {
  set +e
  echo "[cleanup] removing fixtures..."

  curl -sS -X DELETE "$REST_URL/raid_contributions?user_id=eq.${owner_uid}" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" >/dev/null

  [[ -n "$raid_id" ]] && curl -sS -X DELETE "$REST_URL/raid_bosses?id=eq.${raid_id}" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" >/dev/null

  [[ -n "$neighborhood_id" ]] && curl -sS -X DELETE "$REST_URL/neighborhood_members?neighborhood_id=eq.${neighborhood_id}" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" >/dev/null

  [[ -n "$neighborhood_id" ]] && curl -sS -X DELETE "$REST_URL/neighborhoods?id=eq.${neighborhood_id}" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" >/dev/null

  [[ -n "$user_task_id" ]] && curl -sS -X DELETE "$REST_URL/streaks?user_task_id=eq.${user_task_id}" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" >/dev/null

  [[ -n "$user_task_id" ]] && curl -sS -X DELETE "$REST_URL/task_completions?user_task_id=eq.${user_task_id}" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" >/dev/null

  [[ -n "$user_task_id" ]] && curl -sS -X DELETE "$REST_URL/user_tasks?id=eq.${user_task_id}" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" >/dev/null

  curl -sS -X DELETE "$REST_URL/user_inventory?user_id=eq.${owner_uid}" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" >/dev/null

  curl -sS -X DELETE "$REST_URL/user_achievements?user_id=eq.${owner_uid}" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" >/dev/null

  curl -sS -X DELETE "$REST_URL/coin_transactions?user_id=eq.${owner_uid}" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" >/dev/null

  curl -sS -X DELETE "$REST_URL/coin_transactions?user_id=eq.${member_uid}" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" >/dev/null

  curl -sS -X DELETE "$REST_URL/task_catalog?id=eq.${task_catalog_id}" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" >/dev/null

  curl -sS -X DELETE "$REST_URL/shop_items?id=eq.${shop_item_id}" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" >/dev/null

  curl -sS -X DELETE "$REST_URL/achievement_definitions?id=eq.${achievement_id}" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" >/dev/null

  curl -sS -X DELETE "$REST_URL/users?uid=eq.${owner_uid}" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" >/dev/null

  curl -sS -X DELETE "$REST_URL/users?uid=eq.${member_uid}" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" >/dev/null

  echo "[cleanup] done"
}
trap cleanup EXIT

yesterday="$(date -u -v-1d +%F 2>/dev/null || date -u -d '1 day ago' +%F)"

echo "[1/12] Seed users"
users_payload="$(jq -nc --arg owner "$owner_uid" --arg member "$member_uid" '[
  {uid:$owner,name:"Phase4 Owner",title:"Tester",status_total:25000,coins:500,level:12,real_age:30,body_age:30},
  {uid:$member,name:"Phase4 Member",title:"Tester",status_total:500,coins:120,level:5,real_age:29,body_age:29}
]')"
curl -sS -X POST "$REST_URL/users" "${service_headers[@]}" -d "$users_payload" >/dev/null

echo "[2/12] Seed task catalog + user task + streak"
task_payload="$(jq -nc --arg id "$task_catalog_id" '[
  {
    id:$id,
    name:"Phase4 API Workout",
    category:"cardio",
    base_difficulty:4.0,
    duration_min:45,
    body_age_impact:0.05,
    disease_risk_heart:-0.2,
    disease_risk_diabetes:-0.25,
    disease_risk_stroke:-0.15,
    lifespan_impact:0.01,
    calories_burned:500
  }
]')"
curl -sS -X POST "$REST_URL/task_catalog" "${service_headers[@]}" -d "$task_payload" >/dev/null

user_task_resp="$(curl -sS -X POST "$REST_URL/user_tasks" "${service_headers[@]}" -d "$(jq -nc --arg uid "$owner_uid" --arg task "$task_catalog_id" '[{user_id:$uid,task_catalog_id:$task,frequency:5,is_active:true}]')")"
user_task_id="$(echo "$user_task_resp" | jq -r '.[0].id')"
[[ "$user_task_id" != "null" && -n "$user_task_id" ]] || { echo "FAIL: user task creation failed"; exit 1; }

streak_payload="$(jq -nc --arg uid "$owner_uid" --arg ut "$user_task_id" --arg yd "$yesterday" '[
  {
    user_id:$uid,
    user_task_id:$ut,
    count:2,
    longest_count:2,
    last_completed_date:$yd,
    grace_days_remaining:3,
    shield_active:false,
    is_broken:false
  }
]')"
curl -sS -X POST "$REST_URL/streaks" "${service_headers[@]}" -d "$streak_payload" >/dev/null

echo "[3/12] Seed achievement + shop item"
achievement_payload="$(jq -nc --arg id "$achievement_id" '[
  {
    id:$id,
    name:"Phase4 API Achievement",
    description:"Unlock after first completion",
    condition_type:"task_completions",
    condition_value:1,
    reward_status:25,
    reward_coins:15
  }
]')"
curl -sS -X POST "$REST_URL/achievement_definitions" "${service_headers[@]}" -d "$achievement_payload" >/dev/null

shop_payload="$(jq -nc --arg id "$shop_item_id" '[
  {
    id:$id,
    name:"Phase4 API Item",
    category:"building_skin",
    price:90,
    description:"Phase4 API e2e shop item",
    is_active:true
  }
]')"
curl -sS -X POST "$REST_URL/shop_items" "${service_headers[@]}" -d "$shop_payload" >/dev/null

echo "[4/12] Found neighborhood (edge function)"
found_payload="$(jq -nc --arg name "$neighborhood_name" '{name:$name,motto:"API test motto",type:"interest"}')"
found_resp="$(curl -sS -X POST "$FUNC_URL/found-neighborhood" "${func_headers[@]}" -H "x-fitcity-uid: $owner_uid" -d "$found_payload")"
require_true "found-neighborhood success" "$(echo "$found_resp" | jq -r '.success == true')"
neighborhood_id="$(echo "$found_resp" | jq -r '.neighborhoodId')"
[[ "$neighborhood_id" != "null" && -n "$neighborhood_id" ]] || { echo "FAIL: neighborhoodId missing"; exit 1; }

echo "[5/12] Join neighborhood (edge function)"
join_resp="$(curl -sS -X POST "$FUNC_URL/join-neighborhood" "${func_headers[@]}" -H "x-fitcity-uid: $member_uid" -d "$(jq -nc --arg id "$neighborhood_id" '{neighborhoodId:$id}')")"
require_true "join-neighborhood success" "$(echo "$join_resp" | jq -r '.success == true')"

echo "[6/12] Create active raid boss"
raid_deadline="$(date -u -v+2d +%FT%TZ 2>/dev/null || date -u -d '2 days' +%FT%TZ)"
raid_payload="$(jq -nc --arg nid "$neighborhood_id" --arg dl "$raid_deadline" '[
  {
    neighborhood_id:$nid,
    title:"Phase4 API Raid",
    description:"Raid progress realtime source",
    target_value:1000000,
    current_progress:430000,
    unit:"kcal",
    reward_status:100,
    reward_coins:25,
    deadline:$dl,
    is_active:true
  }
]')"
raid_resp="$(curl -sS -X POST "$REST_URL/raid_bosses" "${service_headers[@]}" -d "$raid_payload")"
raid_id="$(echo "$raid_resp" | jq -r '.[0].id')"
[[ "$raid_id" != "null" && -n "$raid_id" ]] || { echo "FAIL: raid creation failed"; exit 1; }

echo "[7/12] Call complete-task (edge function)"
complete_resp="$(curl -sS -X POST "$FUNC_URL/complete-task" "${func_headers[@]}" -H "x-fitcity-uid: $owner_uid" -d "$(jq -nc --arg ut "$user_task_id" '{userTaskId:$ut,verificationType:"auto",healthConnectData:{steps:1200}}')")"
require_true "complete-task returned streakCount" "$(echo "$complete_resp" | jq -r '.streakCount >= 1')"
require_true "complete-task earned coins" "$(echo "$complete_resp" | jq -r '.coinsEarned > 0')"

echo "[8/12] Verify streak + achievement + user updates"
streak_row="$(curl -sS "$REST_URL/streaks?user_id=eq.${owner_uid}&user_task_id=eq.${user_task_id}&select=count,is_broken,last_completed_date" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY")"
require_true "streak updated for completion" "$(echo "$streak_row" | jq -r 'length == 1 and .[0].count >= 1 and .[0].last_completed_date != null')"
require_true "streak not broken" "$(echo "$streak_row" | jq -r '.[0].is_broken == false')"

ach_row="$(curl -sS "$REST_URL/user_achievements?user_id=eq.${owner_uid}&achievement_id=eq.${achievement_id}&select=user_id" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY")"
require_true "achievement unlocked" "$(echo "$ach_row" | jq -r 'length == 1')"

echo "[9/12] Verify raid progress incremented by calories"
raid_after="$(curl -sS "$REST_URL/raid_bosses?id=eq.${raid_id}&select=current_progress" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY")"
require_true "raid progress incremented" "$(echo "$raid_after" | jq -r '.[0].current_progress == 430500')"

echo "[10/12] Call get-leaderboard"
leader_resp="$(curl -sS -X POST "$FUNC_URL/get-leaderboard" "${func_headers[@]}" -H "x-fitcity-uid: $owner_uid" -d '{"timeFrame":"global","limit":20}')"
require_true "get-leaderboard response shape" "$(echo "$leader_resp" | jq -r '(.timeFrame != null) and (.rankings | type == "array")')"
require_true "leaderboard rankings array present" "$(echo "$leader_resp" | jq -r '.rankings | type == "array"')"

echo "[11/12] Purchase item (edge function)"
purchase_resp="$(curl -sS -X POST "$FUNC_URL/purchase-item" "${func_headers[@]}" -H "x-fitcity-uid: $owner_uid" -d "$(jq -nc --arg item "$shop_item_id" '{itemId:$item}')")"
require_true "purchase-item success" "$(echo "$purchase_resp" | jq -r '.success == true')"

inventory_row="$(curl -sS "$REST_URL/user_inventory?user_id=eq.${owner_uid}&item_id=eq.${shop_item_id}&select=user_id,item_id" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY")"
require_true "inventory granted" "$(echo "$inventory_row" | jq -r 'length == 1')"

echo "[12/12] Check users realtime source row changed (coins/status exist)"
user_row="$(curl -sS "$REST_URL/users?uid=eq.${owner_uid}&select=coins,status_total,level" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY")"
require_true "user row fetch valid" "$(echo "$user_row" | jq -r 'length == 1 and .[0].coins >= 0 and .[0].status_total > 2000')"

echo ""
echo "Phase 4 API E2E PASSED"
echo "owner_uid=$owner_uid"
echo "member_uid=$member_uid"
echo "neighborhood_id=$neighborhood_id"
echo "raid_id=$raid_id"