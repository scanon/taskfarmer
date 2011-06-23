
prefix := /usr

NAME	= taskfarmer

BINFILES=	tfrun
SHAREFILES=	share/*.conf share/submit_es.q share/stage.cacher
EXAMPLEFILES=	examples/stage.sh examples/fix_perl_path.sh examples/sample.sh examples/pack.sh \
		examples/blast.qsub examples/stage.cloud.sh examples/sample.qsub examples/run.cloud

BINDIR=		$(prefix)/bin
LIBEXECDIR=	$(prefix)/libexec/$(NAME)
SHAREDIR=	$(prefix)/share/$(NAME)
EXAMPLESDIR=	$(SHAREDIR)/examples

all:

install:
	install -d $(BINDIR)
	install -d $(LIBEXECDIR)
	install -d $(SHAREDIR)
	install -d $(EXAMPLESDIR)
	install tfrun.sh $(BINDIR)/tfrun
	install tf_server.pl $(LIBEXECDIR)/tf_server
	install tf_worker_thread.pl $(LIBEXECDIR)/tf_worker_thread
	install tf_worker $(LIBEXECDIR)/tf_worker
	install -m 644 -t $(SHAREDIR) $(SHAREFILES)
	install -m 644 -t $(EXAMPLESDIR) $(EXAMPLEFILES)
