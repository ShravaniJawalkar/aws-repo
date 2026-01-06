# Solution: Install MySQL Client on Amazon Linux 2

## ISSUE: Package cache expired/metadata not found

## Solution 1: Clear Cache and Use Amazon Linux 2 Extras (MOST RELIABLE)

Run on EC2:
```bash
# 1. Clear yum cache
sudo yum clean all

# 2. Regenerate metadata
sudo yum makecache

# 3. Install MySQL 8.0 from extras
sudo amazon-linux-extras install -y mysql8.0

# 4. Verify
mysql --version
```

---

## Solution 2: Update All Packages First

```bash
# Update everything
sudo yum update -y

# Then install
sudo yum install -y mysql-devel

# Test
mysql --version
```

---

## Solution 3: Python Alternative (GUARANTEED TO WORK - No Packages Needed)

If packages still fail, use Python (pre-installed on EC2):

```bash
# 1. Install PyMySQL
pip3 install pymysql

# 2. Create database setup script
cat > setup_rds.py << 'PYSCRIPT'
import pymysql
import sys

# Configuration
RDS_ENDPOINT = sys.argv[1] if len(sys.argv) > 1 else "webproject-database.xxxxx.ap-south-1.rds.amazonaws.com"
DB_USER = 'admin'
DB_PASSWORD = 'PasswordwebProject2024'
DB_PORT = 3306

try:
    # Test connection
    print("[1/4] Testing RDS connection...")
    conn = pymysql.connect(
        host=RDS_ENDPOINT,
        user=DB_USER,
        password=DB_PASSWORD,
        port=DB_PORT
    )
    print("✓ Connection successful!\n")
    
    cursor = conn.cursor()
    
    # Create database
    print("[2/4] Creating database 'imagedb'...")
    cursor.execute("CREATE DATABASE IF NOT EXISTS imagedb;")
    print("✓ Database created\n")
    
    # Use database
    cursor.execute("USE imagedb;")
    
    # Create table
    print("[3/4] Creating 'image_metadata' table...")
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS image_metadata (
            id INT AUTO_INCREMENT PRIMARY KEY,
            filename VARCHAR(255) NOT NULL UNIQUE,
            size_bytes INT,
            content_type VARCHAR(100),
            s3_key VARCHAR(255),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    print("✓ Table created\n")
    
    # Insert sample data
    print("[4/4] Inserting sample data...")
    cursor.execute("""
        INSERT IGNORE INTO image_metadata (filename, size_bytes, content_type, s3_key) VALUES
        ('test.jpg', 6912, 'image/jpeg', 'test.jpg'),
        ('city.jpg', 5000, 'image/jpeg', 'city.jpg'),
        ('landscape.jpg', 7500, 'image/jpeg', 'landscape.jpg')
    """)
    print("✓ Sample data inserted\n")
    
    # Display results
    print("[✓] Querying data...")
    cursor.execute("SELECT * FROM image_metadata;")
    results = cursor.fetchall()
    print("\nImage Metadata Table:")
    print("-" * 80)
    for row in results:
        print(f"ID: {row[0]}, Filename: {row[1]}, Size: {row[2]} bytes, Type: {row[3]}")
    
    conn.commit()
    conn.close()
    print("\n✓ All operations successful!")
    
except Exception as e:
    print(f"✗ Error: {e}")
    sys.exit(1)

PYSCRIPT

# 3. Run the setup script (replace <RDS_ENDPOINT> with actual endpoint)
python3 setup_rds.py <RDS_ENDPOINT>

# 4. Query the data
python3 << 'EOF'
import pymysql
conn = pymysql.connect(host='<RDS_ENDPOINT>', user='admin', password='PasswordwebProject2024', database='imagedb')
cursor = conn.cursor()
cursor.execute("SELECT filename, size_bytes, content_type FROM image_metadata;")
print("\n✓ Final Query Results:")
for row in cursor.fetchall():
    print(f"  {row[0]} - {row[1]} bytes ({row[2]})")
conn.close()
EOF
```

---

## FASTEST METHOD (3 commands only):

```bash
pip3 install pymysql

python3 << 'EOF'
import pymysql
c = pymysql.connect(host='<RDS_ENDPOINT>', user='admin', password='PasswordwebProject2024')
cur = c.cursor()
cur.execute("CREATE DATABASE IF NOT EXISTS imagedb")
cur.execute("USE imagedb")
cur.execute("""CREATE TABLE IF NOT EXISTS image_metadata (
    id INT AUTO_INCREMENT PRIMARY KEY,
    filename VARCHAR(255),
    size_bytes INT,
    s3_key VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)""")
cur.execute("INSERT INTO image_metadata (filename, size_bytes, s3_key) VALUES ('test.jpg', 6912, 'test.jpg')")
cur.execute("SELECT * FROM image_metadata")
print("✓ Connection & Setup Successful!")
for row in cur.fetchall():
    print(f"  ID: {row[0]}, File: {row[1]}, Size: {row[2]} bytes")
c.commit()
c.close()
EOF
```

---

## Solution 2: Update All Packages First

```bash
# Update everything
sudo yum update -y

# Then install
sudo yum install -y mysql-devel

# Test
mysql --version
```

---

## Solution 3: Python Alternative (No MySQL Client Needed)

---

## Quick Command Sequence:

```bash
# Copy and paste this entire block
sudo yum clean all && \
sudo yum makecache && \
sudo amazon-linux-extras install -y mysql8.0 && \
mysql --version && \
echo "✓ MySQL client installed successfully"
```

---

## Test RDS Connection:

```bash
# Replace <RDS_ENDPOINT> with your actual RDS endpoint
mysql -h <RDS_ENDPOINT> -P 3306 -u admin -pPasswordwebProject2024 -e "SELECT 1 as test;"
```

Expected output:
```
+------+
| test |
+------+
|    1 |
+------+
```
