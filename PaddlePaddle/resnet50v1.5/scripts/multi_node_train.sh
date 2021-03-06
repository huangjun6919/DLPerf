MODEL=${1:-"resnet50"}
gpus=${2:-"0,1,2,3,4,5,6,7"}
BATCH_SIZE=${3:-128}
IMAGE_SIZE=${4:-224}
nodes=${5:-$NODE1,$NODE2,NODE3,$NODE4}
CURRENT_NODE=${6:-NODE1}
TEST_NUM=${7:-1}

a=`expr ${#gpus} + 1`
GPUS_PER_NODE=`expr ${a} / 2`
total_bz=`expr ${BATCH_SIZE} \* ${GPUS_PER_NODE}`
LR=$(awk -v total_bz="$total_bz" 'BEGIN{print  total_bz / 1000}')
node_num=$(echo $nodes | tr ',' '\n' | wc -l)
NUM_EPOCH=`expr ${node_num} \* 4`

echo "Nodes : $nodes"
echo "Use gpus: $gpus"
echo "Batch size : $BATCH_SIZE"
echo "Total batch size : $total_bz"
echo "Learning rate: $LR"


LOG_FOLDER=../paddle/resnet50/${node_num}n${GPUS_PER_NODE}g
mkdir -p $LOG_FOLDER
LOGFILE=${LOG_FOLDER}/r50_b${BATCH_SIZE}_fp32_$TEST_NUM.log


export CUDA_VISIBLE_DEVICES=${gpus}
export FLAGS_fraction_of_gpu_memory_to_use=0.98
DATA_DIR=/datasets/ImageNet/imagenet_1k/

python3 -m paddle.distributed.launch --cluster_node_ips=${nodes} \
--node_ip=$CURRENT_NODE \
train.py \
        --data_dir=${DATA_DIR} \
        --total_images=651468 \
        --class_dim=1000 \
        --validate=False \
        --batch_size=$total_bz \
        --image_shape 3 $IMAGE_SIZE $IMAGE_SIZE \
	--print_step=1 \
	--save_step=10000 \
        --lr_strategy=piecewise_decay \
        --lr=$LR \
        --momentum_rate=0.875 \
        --max_iter=120 \
        --model='ResNet50'  \
        --model_save_dir=output/ \
        --l2_decay=0.000030518 \
        --warm_up_epochs=1 \
        --use_mixup=False \
        --use_label_smoothing=True \
        --label_smoothing_epsilon=0.1  2>&1 | tee ${LOGFILE}

echo "Writting log to ${LOGFILE}"