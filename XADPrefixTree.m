#import "XADPrefixTree.h"

NSString *XADInvalidPrefixCodeException=@"XADInvalidPrefixCodeException";

@implementation XADPrefixTree

static inline int *NodePointer(XADPrefixTree *self,int node) { return self->tree[node]; }

static inline int NewNode(XADPrefixTree *self)
{
	self->tree=reallocf(self->tree,(self->numentries+1)*sizeof(int)*2);
	NodePointer(self,self->numentries)[0]=-1;
	NodePointer(self,self->numentries)[1]=-2;
	return self->numentries++;
}

static inline BOOL IsEmptyNode(XADPrefixTree *self,int node) { return NodePointer(self,node)[0]==-1&&NodePointer(self,node)[1]==-2; }

static inline int Branch(XADPrefixTree *self,int node,int bit) { return NodePointer(self,node)[bit]; }
static inline BOOL IsOpenBranch(XADPrefixTree *self,int node,int bit) { return NodePointer(self,node)[bit]<0; }
static inline void SetBranch(XADPrefixTree *self,int node,int bit,int nextnode) { NodePointer(self,node)[bit]=nextnode; }

static inline int Leaf(XADPrefixTree *self,int node) { return NodePointer(self,node)[0]; }
static inline BOOL IsLeafNode(XADPrefixTree *self,int node) { return NodePointer(self,node)[0]==NodePointer(self,node)[1]; }
static inline void SetLeaf(XADPrefixTree *self,int node,int value) { NodePointer(self,node)[0]=NodePointer(self,node)[1]=value; }


int CSInputNextSymbolFromTree(CSInputBuffer *buf,XADPrefixTree *tree)
{
	int node=0;
	for(;;)
	{
		int bit=CSInputNextBit(buf);
		if(IsOpenBranch(tree,node,bit)) [NSException raise:XADInvalidPrefixCodeException format:@"Invalid prefix code in bitstream"];
		node=Branch(tree,node,bit);
		if(IsLeafNode(tree,node)) return Leaf(tree,node);
	}
}

int CSInputNextSymbolFromTreeLE(CSInputBuffer *buf,XADPrefixTree *tree)
{
	int node=0;
	for(;;)
	{
		int bit=CSInputNextBitLE(buf);
		if(IsOpenBranch(tree,node,bit)) [NSException raise:XADInvalidPrefixCodeException format:@"Invalid prefix code in bitstream"];
		node=Branch(tree,node,bit);
		if(IsLeafNode(tree,node)) return Leaf(tree,node);
	}
}



+(XADPrefixTree *)prefixTree { return [[self new] autorelease]; }

-(id)init
{
	if(self=[super init])
	{
		tree=malloc(sizeof(int)*2);
		tree[0][0]=-1;
		tree[0][1]=-2;
		numentries=1;
		isstatic=NO;
		stack=nil;
	}
	return self;
}

-(id)initWithStaticTable:(int (*)[2])statictable
{
	if(self=[super init])
	{
		tree=statictable;
		isstatic=YES;
	}
	return self;
}

-(void)dealloc
{
	if(!isstatic) free(tree);
	[stack release];
	[super dealloc];
}

-(void)addValue:(int)value forCode:(int)code length:(int)length
{
	[self addValue:value forCode:code length:length repeatAt:length];
}

-(void)addValue:(int)value forCode:(int)code length:(int)length repeatAt:(int)repeatpos
{
	if(isstatic) [NSException raise:NSGenericException format:@"Attempted to add codes to a static prefix tree"];

	repeatpos=length-1-repeatpos;
	if(repeatpos==0||(repeatpos>=0&&(((code>>repeatpos-1)&3)==0||((code>>repeatpos-1)&3)==3)))
	[NSException raise:NSInvalidArgumentException format:@"Invalid repeat position"];

	int lastnode=0;
	for(int bitpos=length-1;bitpos>=0;bitpos--)
	{
		int bit=(code>>bitpos)&1;

		if(IsLeafNode(self,lastnode)) [NSException raise:NSInvalidArgumentException format:@"Prefix found"];

		if(bitpos==repeatpos)
		{
			if(!IsOpenBranch(self,lastnode,bit)) [NSException raise:NSInvalidArgumentException format:@"Invalid repeating code"];

			int repeatnode=NewNode(self);
			int nextnode=NewNode(self);

			SetBranch(self,lastnode,bit,repeatnode);
			SetBranch(self,repeatnode,bit,repeatnode);
			SetBranch(self,repeatnode,bit^1,nextnode);
			lastnode=nextnode;

			bitpos++; // terminating bit already handled, skip it
		}
		else
		{
			if(IsOpenBranch(self,lastnode,bit)) SetBranch(self,lastnode,bit,NewNode(self));
			lastnode=Branch(self,lastnode,bit);
		}

	}

	if(!IsEmptyNode(self,lastnode)) [NSException raise:NSInvalidArgumentException format:@"Prefix found"];
	SetLeaf(self,lastnode,value);
}

-(void)startBuildingTree
{
	currnode=0;
	if(!stack) stack=[NSMutableArray new];
	else [stack removeAllObjects];
}

-(void)startZeroBranch
{
	int new=NewNode(self);
	SetBranch(self,currnode,0,new);
	[self _pushNode];
	currnode=new;
}

-(void)startOneBranch
{
	int new=NewNode(self);
	SetBranch(self,currnode,1,new);
	[self _pushNode];
	currnode=new;
}

-(void)finishBranches
{
	[self _popNode];
}

-(void)makeLeafWithValue:(int)value
{
	SetLeaf(self,currnode,value);
	[self _popNode];
}

-(void)_pushNode
{
	[stack addObject:[NSNumber numberWithInt:currnode]];
}

-(void)_popNode
{
	if(![stack count]) return; // the final pop will underflow the stack otherwise
	NSNumber *num=[stack lastObject];
	[stack removeLastObject];
	currnode=[num intValue];
}

@end
