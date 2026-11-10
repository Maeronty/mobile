mod common;

use common::setup_test_pool;
use food_tip_be_rust::db;
use std::sync::Arc;
use uuid::Uuid;

#[tokio::test]
async fn test_adversarial_30_concurrent_empty_db_seeders_in_memory() {
    let pool = setup_test_pool().await;
    let pool_arc = Arc::new(pool);

    let mut handles = Vec::new();
    let num_tasks = 30;

    for i in 0..num_tasks {
        let p = Arc::clone(&pool_arc);
        handles.push(tokio::spawn(async move {
            let res = db::seed_database(&p).await;
            (i, res)
        }));
    }

    let mut success_count = 0;
    let mut failure_count = 0;

    for h in handles {
        let (task_id, res) = h.await.expect("Join error");
        match res {
            Ok(count) => {
                assert_eq!(count, 8, "Task {} reported non-8 count", task_id);
                success_count += 1;
            }
            Err(e) => {
                failure_count += 1;
                eprintln!("Task {} failed with error: {:?}", task_id, e);
            }
        }
    }

    assert_eq!(
        failure_count, 0,
        "Zero tasks should fail during concurrent seeding"
    );
    assert_eq!(
        success_count, num_tasks,
        "All {} tasks must succeed",
        num_tasks
    );

    // Verify row counts across all related tables
    let (recipe_count,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipes")
        .fetch_one(pool_arc.as_ref())
        .await
        .unwrap();
    assert_eq!(recipe_count, 8, "Expected exactly 8 recipes in DB");

    let (nut_count,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_nutritions")
        .fetch_one(pool_arc.as_ref())
        .await
        .unwrap();
    assert_eq!(nut_count, 8, "Expected exactly 8 recipe nutritions");

    let (ing_count,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_ingredients")
        .fetch_one(pool_arc.as_ref())
        .await
        .unwrap();
    assert!(ing_count >= 40, "Expected at least 40 ingredients");

    let (inst_count,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_instructions")
        .fetch_one(pool_arc.as_ref())
        .await
        .unwrap();
    assert!(inst_count >= 20, "Expected at least 20 instructions");
}

#[tokio::test]
async fn test_adversarial_30_concurrent_empty_db_seeders_on_disk_wal() {
    let temp_dir = std::env::temp_dir();
    let db_path = temp_dir.join(format!("food_tip_seed_stress_{}.db", Uuid::new_v4()));
    let db_path_str = db_path.to_str().unwrap().replace('\\', "/");
    let db_url = format!("sqlite://{}", db_path_str);

    let pool = db::create_pool(&db_url)
        .await
        .expect("Failed to create file-based sqlite pool");

    db::run_migrations(&pool)
        .await
        .expect("Failed to run migrations on file test db");

    let pool_arc = Arc::new(pool);
    let mut handles = Vec::new();
    let num_tasks = 30;

    for i in 0..num_tasks {
        let p = Arc::clone(&pool_arc);
        handles.push(tokio::spawn(async move {
            let res = db::seed_database(&p).await;
            (i, res)
        }));
    }

    let mut success_count = 0;
    let mut failure_count = 0;

    for h in handles {
        let (task_id, res) = h.await.expect("Join error");
        match res {
            Ok(count) => {
                assert_eq!(count, 8, "Task {} reported non-8 count", task_id);
                success_count += 1;
            }
            Err(e) => {
                failure_count += 1;
                eprintln!("Task {} failed on disk WAL: {:?}", task_id, e);
            }
        }
    }

    assert_eq!(
        failure_count, 0,
        "Zero tasks should fail during on-disk WAL concurrent seeding"
    );
    assert_eq!(
        success_count, num_tasks,
        "All {} tasks must succeed on disk WAL",
        num_tasks
    );

    let (recipe_count,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipes")
        .fetch_one(pool_arc.as_ref())
        .await
        .unwrap();
    assert_eq!(recipe_count, 8, "Expected exactly 8 recipes on disk");

    // Clean up temporary database file
    pool_arc.close().await;
    let _ = std::fs::remove_file(&db_path);
    let _ = std::fs::remove_file(format!("{}-wal", db_path.to_str().unwrap()));
    let _ = std::fs::remove_file(format!("{}-shm", db_path.to_str().unwrap()));
}

#[tokio::test]
async fn test_adversarial_concurrent_readers_during_empty_db_seeding() {
    let pool = setup_test_pool().await;
    let pool_arc = Arc::new(pool);

    let mut seed_handles = Vec::new();
    let mut read_handles = Vec::new();

    // 10 concurrent seeders
    for i in 0..10 {
        let p = Arc::clone(&pool_arc);
        seed_handles.push(tokio::spawn(async move {
            let res = db::seed_database(&p).await;
            (i, res)
        }));
    }

    // 20 concurrent readers querying recipe count simultaneously
    for i in 0..20 {
        let p = Arc::clone(&pool_arc);
        read_handles.push(tokio::spawn(async move {
            let res: Result<(i64,), sqlx::Error> =
                sqlx::query_as("SELECT COUNT(*) FROM recipes")
                    .fetch_one(p.as_ref())
                    .await;
            (i, res)
        }));
    }

    for h in seed_handles {
        let (task_id, res) = h.await.expect("Seed join error");
        assert!(
            res.is_ok(),
            "Seeder {} failed unexpectedly: {:?}",
            task_id,
            res.err()
        );
        assert_eq!(res.unwrap(), 8);
    }

    for h in read_handles {
        let (task_id, res) = h.await.expect("Reader join error");
        assert!(
            res.is_ok(),
            "Reader {} failed unexpectedly: {:?}",
            task_id,
            res.err()
        );
        let count = res.unwrap().0;
        // Due to transactional snapshot isolation, reader must see either 0 (before commit) or 8 (after commit), never partial data
        assert!(
            count == 0 || count == 8,
            "Reader {} observed partial uncommitted data: {} recipes",
            task_id,
            count
        );
    }

    let (final_count,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipes")
        .fetch_one(pool_arc.as_ref())
        .await
        .unwrap();
    assert_eq!(final_count, 8);
}
